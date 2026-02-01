/**
 * lagrange.c - Lagrange interpolation over GF(2^n)
 */

#include "lagrange.h"

uint32_t lagrange_interpolate_at_zero(const share_t *shares, size_t k,
                                      gf_field_t field) {
  if (shares == NULL || k == 0)
    return 0;

  uint32_t secret = 0;

  for (size_t i = 0; i < k; i++) {
    uint32_t numerator = 1;
    uint32_t denominator = 1;

    for (size_t j = 0; j < k; j++) {
      if (i == j)
        continue;
      numerator = gf_mult(numerator, shares[j].x, field);
      denominator =
          gf_mult(denominator, gf_sub(shares[i].x, shares[j].x), field);
    }

    uint32_t lagrange_coeff = gf_div(numerator, denominator, field);
    uint32_t term = gf_mult(shares[i].y, lagrange_coeff, field);
    secret = gf_add(secret, term);
  }

  return secret;
}

uint32_t lagrange_interpolate(const share_t *shares, size_t k, uint32_t x,
                              gf_field_t field) {
  if (shares == NULL || k == 0)
    return 0;

  uint32_t result = 0;

  for (size_t i = 0; i < k; i++) {
    uint32_t numerator = 1;
    uint32_t denominator = 1;

    for (size_t j = 0; j < k; j++) {
      if (i == j)
        continue;
      numerator = gf_mult(numerator, gf_sub(x, shares[j].x), field);
      denominator =
          gf_mult(denominator, gf_sub(shares[i].x, shares[j].x), field);
    }

    uint32_t lagrange_coeff = gf_div(numerator, denominator, field);
    uint32_t term = gf_mult(shares[i].y, lagrange_coeff, field);
    result = gf_add(result, term);
  }

  return result;
}
