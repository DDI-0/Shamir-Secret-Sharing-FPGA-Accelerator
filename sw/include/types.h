/**
 * types.h - Common types for Shamir's Secret Sharing over GF(2^n)
 */

#ifndef SHAMIR_TYPES_H
#define SHAMIR_TYPES_H

#include "gf.h"
#include <stddef.h>
#include <stdint.h>

#define MAX_SHARES 255
#define MAX_THRESHOLD 16

/* A share is a point (x, y) on the polynomial */
typedef struct {
  uint32_t x;
  uint32_t y;
} share_t;

/* Result codes */
typedef enum {
  SHAMIR_OK = 0,
  SHAMIR_ERROR_INVALID_PARAMS,
  SHAMIR_ERROR_RANDOM_FAILED,
  SHAMIR_ERROR_DUPLICATE_X,
  SHAMIR_ERROR_DIVISION_BY_ZERO
} shamir_error_t;

#endif 