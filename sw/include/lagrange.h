/**
 * lagrange.h - Lagrange interpolation over GF(2^n)
 */

#ifndef LAGRANGE_H
#define LAGRANGE_H

#include "gf.h"
#include "types.h"
#include <stddef.h>
#include <stdint.h>

/**
 * Lagrange interpolation to find f(0) - used for secret reconstruction
 */
uint32_t lagrange_interpolate_at_zero(const share_t *shares, size_t k,
                                      gf_field_t field);

/**
 * Lagrange interpolation at arbitrary point x
 */
uint32_t lagrange_interpolate(const share_t *shares, size_t k, uint32_t x,
                              gf_field_t field);

#endif /* LAGRANGE_H */
