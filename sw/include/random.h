/**
 * random number generation
 */

#ifndef RANDOM_H
#define RANDOM_H

#include <stddef.h>
#include <stdint.h>

int generate_random_bytes(void *buf, size_t len);

uint64_t generate_random_mod(uint64_t max);

#endif
