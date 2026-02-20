/**
 * fpga_driver.c - FPGA Driver Implementation (Avalon-MM)
 * Multi-Mode Shamir Accelerator
 */

#include "fpga_driver.h"
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

/* Share register LUT*/
static const int share_x_regs[MAX_SHARES] = {
    REG_SHARE_X0, REG_SHARE_X1, REG_SHARE_X2, REG_SHARE_X3,
    REG_SHARE_X4, REG_SHARE_X5, REG_SHARE_X6, REG_SHARE_X7};

static const int share_y_regs[MAX_SHARES] = {
    REG_SHARE_Y0, REG_SHARE_Y1, REG_SHARE_Y2, REG_SHARE_Y3,
    REG_SHARE_Y4, REG_SHARE_Y5, REG_SHARE_Y6, REG_SHARE_Y7};

/* Coefficient register LUT*/
static const int coeff_regs[MAX_SHARES] = {REG_COEFF0, REG_COEFF1, REG_COEFF2,
                                           REG_COEFF3, REG_COEFF4, REG_COEFF5,
                                           REG_COEFF6, REG_COEFF7};

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

/* ============== Mode 0: Brute Force ============== */

void fpga_brute_start(fpga_handle_t *h, int field, uint32_t share_x,
                      uint32_t share_y, uint32_t coeff_a1, uint32_t coeff_a2) {
  fpga_write(h, REG_FIELD, field);
  fpga_write(h, REG_SHARE_X0, share_x);
  fpga_write(h, REG_SHARE_Y0, share_y);
  fpga_write(h, REG_COEFF0, coeff_a1);
  fpga_write(h, REG_COEFF1, coeff_a2);
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

/* ============== Mode 1: Share Generation ============== */

uint32_t fpga_generate_share(fpga_handle_t *h, int field, uint32_t secret,
                             const uint32_t *coeffs, int degree, uint32_t x) {
  if (degree < 0 || degree > MAX_DEGREE)
    return 0;

  /* Set field */
  fpga_write(h, REG_FIELD, field);

  /* a0 = secret */
  fpga_write(h, REG_COEFF0, secret);

  /* Load coefficients a1..a7 */
  for (int i = 1; i <= degree; i++) {
    fpga_write(h, coeff_regs[i], (coeffs && i <= degree) ? coeffs[i - 1] : 0);
  }

  /* Zero out unused coefficient registers */
  for (int i = degree + 1; i < MAX_SHARES; i++) {
    fpga_write(h, coeff_regs[i], 0);
  }

  /* Set degree and evaluation point */
  fpga_write(h, REG_K_DEGREE, degree);
  fpga_write(h, REG_EVAL_X, x);

  /* Mode 1 (generate) + start */
  fpga_write(h, REG_CONTROL, (MODE_GENERATE << CTRL_MODE_SHIFT) | CTRL_START);

  int timeout = 100000;
  uint32_t st;
  do {
    st = fpga_read(h, REG_STATUS);
  } while ((st & STAT_BUSY) && !(st & STAT_DONE) && --timeout > 0);

  return fpga_read(h, REG_RESULT);
}

/* ============== Mode 2: Secret Reconstruction ============== */

uint32_t fpga_reconstruct(fpga_handle_t *h, int field,
                          const fpga_share_t *shares, int k) {
  if (k < 2 || k > MAX_SHARES)
    return 0;

  /* Set field */
  fpga_write(h, REG_FIELD, field);

  /* Load all k shares */
  for (int i = 0; i < k; i++) {
    fpga_write(h, share_x_regs[i], shares[i].x);
    fpga_write(h, share_y_regs[i], shares[i].y);
  }

  /* Set k value */
  fpga_write(h, REG_K_DEGREE, k);

  /* Mode 2 (reconstruct) + start */
  fpga_write(h, REG_CONTROL,
             (MODE_RECONSTRUCT << CTRL_MODE_SHIFT) | CTRL_START);

  int timeout = 100000;
  uint32_t st;
  do {
    st = fpga_read(h, REG_STATUS);
  } while ((st & STAT_BUSY) && !(st & STAT_DONE) && --timeout > 0);

  return fpga_read(h, REG_RESULT);
}
