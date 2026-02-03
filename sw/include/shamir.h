/**
 * shamir.h - Shamir's Secret Sharing over GF(2^n)
 */

#ifndef SHAMIR_H
#define SHAMIR_H

#include "gf.h"
#include "types.h"
#include <stddef.h>
#include <stdint.h>

/**
 * Shamir library
 */
void shamir_init(void);

/**
 * Split secret into n shares, requiring k to reconstruct
 */
shamir_error_t shamir_split(uint32_t secret, size_t k, size_t n,
                            gf_field_t field, share_t *shares);

/**
 * Reconstruct secret from k shares
 */
uint32_t shamir_reconstruct(const share_t *shares, size_t k, gf_field_t field);

/**
 * Generate new share at specific x value
 */
share_t shamir_generate_share(const share_t *shares, size_t k, uint32_t new_x,
                              gf_field_t field);

#endif
