/**
 * gf.h - GF(2^n) Binary Finite Field Arithmetic
 * Supports: GF(2^8), GF(2^16), GF(2^32)
 * Uses carry-less multiplication
 */

#ifndef GF_H
#define GF_H

#include <stdint.h>

// field sizes
typedef enum { GF_8 = 8, GF_16 = 16, GF_32 = 32 } gf_field_t;

// polynomials
//  polys chosen for minimal XOR gates in FPGA reduction
#define GF8_POLY 0x11B    // x^8 + x^4 + x^3 + x + 1
#define GF16_POLY 0x1100B // x^16 + x^12 + x^3 + x + 1
#define GF32_POLY 0x8DUL  // x^32 + x^7 + x^3 + x^2 + 1 

void gf_init(void);

// GF(2^n) addition: a XOR b
static inline uint32_t gf_add(uint32_t a, uint32_t b) { return a ^ b; }

// GF(2^n) subtraction:a XOR b
static inline uint32_t gf_sub(uint32_t a, uint32_t b) { return a ^ b; }

// GF(2^n) multiplication
uint32_t gf_mult(uint32_t a, uint32_t b, gf_field_t field);

// GF(2^n) multiplicative inverse
uint32_t gf_inv(uint32_t a, gf_field_t field);

// GF(2^n) division: a / b
static inline uint32_t gf_div(uint32_t a, uint32_t b, gf_field_t field) {
  if (b == 0)
    return 0;
  return gf_mult(a, gf_inv(b, field), field);
}

// GF(2^n) exponentiation: a^exp
uint32_t gf_exp(uint32_t base, uint32_t exp, gf_field_t field);

// Field mask for given size
static inline uint32_t gf_mask(gf_field_t field) {
  return (field == 32) ? 0xFFFFFFFFU : ((1U << field) - 1);
}

#endif /* GF_H */
