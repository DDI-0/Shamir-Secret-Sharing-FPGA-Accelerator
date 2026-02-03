/**
 * poly.c - Polynomial operations over GF(2^n)
 */

#include "poly.h"

uint32_t poly_eval(const uint32_t *coeffs, size_t degree, uint32_t x,
                   gf_field_t field) {
  if (coeffs == NULL)
    return 0;

  if (degree == 0) {
    return coeffs[0] & gf_mask(field);
  }

  /* Horner's method */
  uint32_t result = coeffs[degree] & gf_mask(field);

  for (int i = (int)degree - 1; i >= 0; i--) {
    result = gf_mult(result, x, field);
    result = gf_add(result, coeffs[i]);
  }

  return result & gf_mask(field);
}
