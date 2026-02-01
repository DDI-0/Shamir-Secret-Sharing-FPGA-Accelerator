/**
 * random.c - Cryptographic random number generation
 *
 * Uses /dev/urandom for cryptographically secure random bytes.
 * This is the standard approach for crypto applications on Linux.
 */

#include "random.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

int generate_random_bytes(void *buf, size_t len) {
  if (buf == NULL || len == 0) {
    return -1;
  }

  int fd = open("/dev/urandom", O_RDONLY);
  if (fd < 0) {
    perror("open /dev/urandom");
    return -1;
  }

  size_t total_read = 0;
  uint8_t *ptr = (uint8_t *)buf;

  while (total_read < len) {
    ssize_t n = read(fd, ptr + total_read, len - total_read);
    if (n < 0) {
      if (errno == EINTR)
        continue;
      perror("read /dev/urandom");
      close(fd);
      return -1;
    }
    total_read += (size_t)n;
  }

  close(fd);
  return 0;
}

uint64_t generate_random_mod(uint64_t max) {
  if (max == 0)
    return 0;
  if (max == 1)
    return 0;

  uint64_t value;

  /* Rejection sampling to avoid modulo bias */
  uint64_t threshold = -max % max; /* 2^64 mod max */

  do {
    if (generate_random_bytes(&value, sizeof(value)) < 0) {
      return 0;
    }
  } while (value < threshold);

  return value % max;
}
