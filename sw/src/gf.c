/**
 * gf.c - GF(2^n) Binary Finite Field Arithmetic
 */

#include "gf.h"

/* 8-bit lookup tables */
static uint8_t gf8_log[256];
static uint8_t gf8_exp[512];
static int gf_initialized = 0;

/**
 * Carry-less multiply
 */
static uint64_t clmul(uint32_t a, uint32_t b) {
  uint64_t result = 0;
  uint64_t shifted_a = a;

  while (b) {
    if (b & 1) {
      result ^= shifted_a;
    }
    shifted_a <<= 1;
    b >>= 1;
  }
  return result;
}

/**
 * Reduce by irreducible polynomial
 */
static uint32_t gf_reduce(uint64_t product, gf_field_t field) {
  int bits = (int)field;
  uint32_t mask = gf_mask(field);
  uint32_t poly;

  switch (field) {
  case GF_8:
    poly = 0x1B;
    break;
  case GF_16:
    poly = 0x100B;
    break;
  case GF_32:
    poly = 0x8D; //: x^7+x^3+x^2+1
    break;
  default:
    return 0;
  }

  /* Reduce high bits */
  for (int i = 2 * bits - 1; i >= bits; i--) {
    if (product & (1ULL << i)) {
      product ^= ((uint64_t)poly << (i - bits));
      product ^= (1ULL << i);
    }
  }

  return (uint32_t)(product & mask);
}

/**
 * GF8 multiply using tables
 */
static uint8_t gf8_mult_table(uint8_t a, uint8_t b) {
  if (a == 0 || b == 0)
    return 0;
  return gf8_exp[gf8_log[a] + gf8_log[b]];
}

void gf_init(void) {
  if (gf_initialized)
    return;

  /* Build GF(2^8) tables using generator 3 */
  uint16_t x = 1;

  for (int i = 0; i < 255; i++) {
    gf8_exp[i] = (uint8_t)x;
    gf8_exp[i + 255] = (uint8_t)x;
    gf8_log[(uint8_t)x] = (uint8_t)i;

    /* x = x * 3 in GF(256) */
    uint16_t x2 = x << 1;
    if (x2 & 0x100)
      x2 ^= 0x11B;
    x = x2 ^ x;
    if (x & 0x100)
      x ^= 0x11B;
  }
  gf8_log[0] = 0;
  gf8_log[1] = 0;

  gf_initialized = 1;
}

uint32_t gf_mult(uint32_t a, uint32_t b, gf_field_t field) {
  if (a == 0 || b == 0)
    return 0;

  /* Fast path for GF(2^8) */
  if (field == GF_8 && gf_initialized) {
    return gf8_mult_table((uint8_t)a, (uint8_t)b);
  }

  uint32_t mask = gf_mask(field);
  a &= mask;
  b &= mask;

  uint64_t product = clmul(a, b);
  return gf_reduce(product, field);
}

uint32_t gf_inv(uint32_t a, gf_field_t field) {
  if (a == 0)
    return 0;

  /* Fast path for GF(2^8) */
  if (field == GF_8 && gf_initialized) {
    if (gf8_log[(uint8_t)a] == 0 && a != 1) {
      return gf_exp(a, 254, field);
    }
    return gf8_exp[255 - gf8_log[(uint8_t)a]];
  }

  /* Fermat's little theorem: a^(-1) = a^(2^n - 2) */
  uint32_t exp_val = gf_mask(field) - 1; /* 2^n - 2 = (2^n - 1) - 1 */
  return gf_exp(a, exp_val, field);
}

uint32_t gf_exp(uint32_t base, uint32_t exp, gf_field_t field) {
  if (base == 0)
    return (exp == 0) ? 1 : 0;
  if (exp == 0)
    return 1;

  uint32_t result = 1;
  base &= gf_mask(field);

  while (exp > 0) {
    if (exp & 1) {
      result = gf_mult(result, base, field);
    }
    exp >>= 1;
    if (exp > 0) {
      base = gf_mult(base, base, field);
    }
  }

  return result;
}
