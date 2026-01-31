/**

 * fpga_driver.h - FPGA Driver for Multi-Mode Shamir Accelerator (Avalon-MM) * 

 * Modes:

 *   0 - Brute-force attack

 *   1 - Share generation (polynomial evaluation)

 *   2 - Secret reconstruction (Lagrange interpolation)

 */



#ifndef FPGA_DRIVER_H

#define FPGA_DRIVER_H



#include <stdint.h>



#include "hps_0.h"



/* HPS-to-FPGA Lightweight Bridge */

#define HPS_LW_BRIDGE_BASE 0xFF200000

#define HPS_LW_BRIDGE_SPAN 0x00200000



/* Shamir IP offset (from hps_0.h) */

#define SHAMIR_BASE_OFFSET SHAMIR_C3_CORE_0_BASE



/* Register offsets  */

#define REG_CONTROL    0   /* 0x00 - Control: start, abort, mode, int */

#define REG_STATUS     1   /* 0x04 - Status: busy, found, done, int_pend */

#define REG_FIELD      2   /* 0x08 - Field selector */

#define REG_SHARE_X0   3   /* 0x0C - Share 0 X / brute X */

#define REG_SHARE_Y0   4   /* 0x10 - Share 0 Y / brute Y */

#define REG_COEFF0     5   /* 0x14 - Coefficient 0 (a0/secret for gen, a1 for brute) */

#define REG_RESULT     6   /* 0x18 - Result output */

#define REG_CYCLES     7   /* 0x1C - Cycle counter (brute only) */

#define REG_SHARE_X1   8   /* 0x20 - Share 1 X */

#define REG_SHARE_Y1   9   /* 0x24 - Share 1 Y */

#define REG_SHARE_X2   10  /* 0x28 - Share 2 X */

#define REG_SHARE_Y2   11  /* 0x2C - Share 2 Y */

#define REG_SHARE_X3   12  /* 0x30 - Share 3 X */

#define REG_SHARE_Y3   13  /* 0x34 - Share 3 Y */

#define REG_COEFF1     14  /* 0x38 - Coefficient 1 (a1) */

#define REG_COEFF2     15  /* 0x3C - Coefficient 2 (a2) */

#define REG_COEFF3     16  /* 0x40 - Coefficient 3 (a3) */

#define REG_K_DEGREE   17  /* 0x44 - k (recon) / degree (gen) */

#define REG_EVAL_X     18  /* 0x48 - X value for share generation */



/* Control register bits */

#define CTRL_START    (1 << 0)

#define CTRL_ABORT    (1 << 1)

#define CTRL_INT_CLR  (1 << 2)

#define CTRL_INT_EN   (1 << 3)

#define CTRL_MODE_SHIFT 4

#define CTRL_MODE_MASK  0x30



/* Status register bits */

#define STAT_BUSY     (1 << 0)

#define STAT_FOUND    (1 << 1)

#define STAT_DONE     (1 << 2)

#define STAT_INT_PEND (1 << 3)



/* Mode values */

#define MODE_BRUTE      0

#define MODE_GENERATE   1

#define MODE_RECONSTRUCT 2



/* Field values */

#define FIELD_GF8   0

#define FIELD_GF16  1

#define FIELD_GF32  2



/* Driver handle */

typedef struct {

  int fd;

  volatile uint32_t *base;

} fpga_handle_t;



/* Share structure */

typedef struct {

  uint32_t x;

  uint32_t y;

} fpga_share_t;



/* Core API  */



/* Open/close */

fpga_handle_t *fpga_open(void);

void fpga_close(fpga_handle_t *h);



/* Register access */

static inline void fpga_write(fpga_handle_t *h, int reg, uint32_t val) {

  h->base[reg] = val;

}



static inline uint32_t fpga_read(fpga_handle_t *h, int reg) {

  return h->base[reg];

}



/*  Mode 0: Brute Force  */

void fpga_brute_start(fpga_handle_t *h, int field, uint32_t share_x,

                      uint32_t share_y, uint32_t coeff);

int fpga_brute_busy(fpga_handle_t *h);

void fpga_brute_result(fpga_handle_t *h, int *found, uint32_t *secret,

                       uint32_t *cycles);



/*  Mode 1: Share Generation  */

uint32_t fpga_generate_share(fpga_handle_t *h, int field, uint32_t secret,

                             const uint32_t *coeffs, int degree, uint32_t x);



/*  Mode 2: Secret Reconstruction  */

uint32_t fpga_reconstruct(fpga_handle_t *h, int field,

                          const fpga_share_t *shares, int k);



#endif