/**
 * poly.h - Polynomial operations over GF(2^n)
 */

#ifndef POLY_H
#define POLY_H

#include "gf.h"
#include <stddef.h>
#include <stdint.h>

/**
 * Evaluate polynomial at point x using Horner's method
 */
uint32_t poly_eval(const uint32_t *coeffs, size_t degree, uint32_t x,
                   gf_field_t field);

#endif 
