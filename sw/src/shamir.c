/**
 * shamir.c - Shamir's Secret Sharing over GF(2^n)
 */

#include "shamir.h"
#include "lagrange.h"
#include "poly.h"
#include "random.h"
#include <string.h>

void shamir_init(void) { gf_init(); }

shamir_error_t shamir_split(uint32_t secret, size_t k, size_t n,
                            gf_field_t field, share_t *shares) {
  if (k < 2 || k > MAX_THRESHOLD)
    return SHAMIR_ERROR_INVALID_PARAMS;
  if (n < k || n > MAX_SHARES)
    return SHAMIR_ERROR_INVALID_PARAMS;
  if (shares == NULL)
    return SHAMIR_ERROR_INVALID_PARAMS;

  uint32_t mask = gf_mask(field);
  secret &= mask;

  /* Create polynomial */
  uint32_t coeffs[MAX_THRESHOLD];
  coeffs[0] = secret;

  /* Generate random coefficients */
  size_t coeff_bytes = (field + 7) / 8;
  for (size_t i = 1; i < k; i++) {
    coeffs[i] = 0;
    if (generate_random_bytes(&coeffs[i], coeff_bytes) < 0) {
      return SHAMIR_ERROR_RANDOM_FAILED;
    }
    coeffs[i] &= mask;
    if (coeffs[i] == 0 && i == k - 1)
      coeffs[i] = 1;
  }

  /* Generate shares at x = 1, 2, ..., n */
  for (size_t i = 0; i < n; i++) {
    shares[i].x = (uint32_t)(i + 1);
    shares[i].y = poly_eval(coeffs, k - 1, shares[i].x, field);
  }

  memset(coeffs, 0, sizeof(coeffs));
  return SHAMIR_OK;
}

uint32_t shamir_reconstruct(const share_t *shares, size_t k, gf_field_t field) {
  if (shares == NULL || k < 2)
    return 0;

  /* Validate shares */
  for (size_t i = 0; i < k; i++) {
    if (shares[i].x == 0)
      return 0;
    for (size_t j = i + 1; j < k; j++) {
      if (shares[i].x == shares[j].x)
        return 0;
    }
  }

  return lagrange_interpolate_at_zero(shares, k, field);
}

share_t shamir_generate_share(const share_t *shares, size_t k, uint32_t new_x,
                              gf_field_t field) {
  share_t new_share = {0, 0};

  if (shares == NULL || k < 2 || new_x == 0)
    return new_share;

  for (size_t i = 0; i < k; i++) {
    if (shares[i].x == new_x)
      return new_share;
  }

  new_share.x = new_x;
  new_share.y = lagrange_interpolate(shares, k, new_x, field);
  return new_share;
}
