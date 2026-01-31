/**
 * FPGA Driver Implementation (Avalon-MM)
 * Multi-Mode Shamir Accelerator
 */

#include "fpga_driver.h"
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

fpga_handle_t *fpga_open(void) {
  fpga_handle_t *h = malloc(sizeof(fpga_handle_t));
  if (!h)
    return NULL;

  h->fd = open("/dev/mem", O_RDWR | O_SYNC);
  if (h->fd < 0) {
    perror("fpga_open: cannot open /dev/mem");
    free(h);
    return NULL;
  }

  void *mapped = mmap(NULL, HPS_LW_BRIDGE_SPAN, PROT_READ | PROT_WRITE,
                      MAP_SHARED, h->fd, HPS_LW_BRIDGE_BASE);

  if (mapped == MAP_FAILED) {
    perror("fpga_open: mmap failed");
    close(h->fd);
    free(h);
    return NULL;
  }

  h->base = (volatile uint32_t *)((char *)mapped + SHAMIR_BASE_OFFSET);
  return h;
}

void fpga_close(fpga_handle_t *h) {
  if (!h)
    return;
  if (h->base) {
    munmap((void *)((char *)h->base - SHAMIR_BASE_OFFSET), HPS_LW_BRIDGE_SPAN);
  }
  if (h->fd >= 0)
    close(h->fd);
  free(h);
}

/* Mode 0: Brute Force  */

void fpga_brute_start(fpga_handle_t *h, int field, uint32_t share_x,
                      uint32_t share_y, uint32_t coeff) {
  fpga_write(h, REG_FIELD, field);
  fpga_write(h, REG_SHARE_X0, share_x);
  fpga_write(h, REG_SHARE_Y0, share_y);
  fpga_write(h, REG_COEFF0, coeff);
  /* Mode 0 (brute) + start */
  fpga_write(h, REG_CONTROL, (MODE_BRUTE << CTRL_MODE_SHIFT) | CTRL_START);
}

int fpga_brute_busy(fpga_handle_t *h) {
  return (fpga_read(h, REG_STATUS) & STAT_BUSY) ? 1 : 0;
}

void fpga_brute_result(fpga_handle_t *h, int *found, uint32_t *secret,
                       uint32_t *cycles) {
  uint32_t status = fpga_read(h, REG_STATUS);
  if (found)
    *found = (status & STAT_FOUND) ? 1 : 0;
  if (secret)
    *secret = fpga_read(h, REG_RESULT);
  if (cycles)
    *cycles = fpga_read(h, REG_CYCLES);
}

/*  Mode 1: Share Generation  */

uint32_t fpga_generate_share(fpga_handle_t *h, int field, uint32_t secret,
                             const uint32_t *coeffs, int degree, uint32_t x) {
  /* Set field */
  fpga_write(h, REG_FIELD, field);
  
  /* Set coefficients: a0 = secret */
  fpga_write(h, REG_COEFF0, secret);
  
  /* Set a1, a2, a3 from coeffs array */
  if (degree >= 1 && coeffs)
    fpga_write(h, REG_COEFF1, coeffs[0]);
  else
    fpga_write(h, REG_COEFF1, 0);
    
  if (degree >= 2 && coeffs)
    fpga_write(h, REG_COEFF2, coeffs[1]);
  else
    fpga_write(h, REG_COEFF2, 0);
    
  if (degree >= 3 && coeffs)
    fpga_write(h, REG_COEFF3, coeffs[2]);
  else
    fpga_write(h, REG_COEFF3, 0);
  
  /* Set degree and evaluation point */
  fpga_write(h, REG_K_DEGREE, degree);
  fpga_write(h, REG_EVAL_X, x);
  
  /* Mode 1 (generate) + start */
  fpga_write(h, REG_CONTROL, (MODE_GENERATE << CTRL_MODE_SHIFT) | CTRL_START);
  
  /* Wait for completion with timeout */
  int timeout = 100000;
  while (!(fpga_read(h, REG_STATUS) & STAT_DONE) && timeout > 0) {
    timeout--;
  }
  
  if (timeout == 0) {
    /* Timeout - read whatever result is there */
    return fpga_read(h, REG_RESULT);
  }
  
  return fpga_read(h, REG_RESULT);
}

/*  Mode 2: Secret Reconstruction  */

uint32_t fpga_reconstruct(fpga_handle_t *h, int field,
                          const fpga_share_t *shares, int k) {
  /* Set field */
  fpga_write(h, REG_FIELD, field);
  
  /* Load shares (up to 4) */
  if (k >= 1) {
    fpga_write(h, REG_SHARE_X0, shares[0].x);
    fpga_write(h, REG_SHARE_Y0, shares[0].y);
  }
  if (k >= 2) {
    fpga_write(h, REG_SHARE_X1, shares[1].x);
    fpga_write(h, REG_SHARE_Y1, shares[1].y);
  }
  if (k >= 3) {
    fpga_write(h, REG_SHARE_X2, shares[2].x);
    fpga_write(h, REG_SHARE_Y2, shares[2].y);
  }
  if (k >= 4) {
    fpga_write(h, REG_SHARE_X3, shares[3].x);
    fpga_write(h, REG_SHARE_Y3, shares[3].y);
  }
  
  /* Set k value */
  fpga_write(h, REG_K_DEGREE, k);
  
  /* Mode 2 (reconstruct) + start */
  fpga_write(h, REG_CONTROL, (MODE_RECONSTRUCT << CTRL_MODE_SHIFT) | CTRL_START);
  
  /* Wait for completion with timeout */
  int timeout = 100000;
  while (!(fpga_read(h, REG_STATUS) & STAT_DONE) && timeout > 0) {
    timeout--;
  }
  
  return fpga_read(h, REG_RESULT);
}
