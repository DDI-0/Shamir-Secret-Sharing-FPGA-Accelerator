// main.c - Shamir FPGA Accelerator CLI

#include "fpga_driver.h"
#include "random.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// Helpers
static const char *field_name(int f) {
  switch (f) {
  case FIELD_GF8:
    return "GF(2^8)";
  case FIELD_GF16:
    return "GF(2^16)";
  case FIELD_GF32:
    return "GF(2^32)";
  default:
    return "unknown";
  }
}

static uint32_t field_mask(int f) {
  switch (f) {
  case FIELD_GF8:
    return 0xFF;
  case FIELD_GF16:
    return 0xFFFF;
  case FIELD_GF32:
    return 0xFFFFFFFF;
  default:
    return 0;
  }
}

static int read_hex(const char *prompt, uint32_t *out) {
  printf("%s", prompt);
  char buf[64];
  if (!fgets(buf, sizeof(buf), stdin))
    return -1;
  *out = (uint32_t)strtoul(buf, NULL, 16);
  return 0;
}

static int read_int(const char *prompt, int *out) {
  printf("%s", prompt);
  char buf[64];
  if (!fgets(buf, sizeof(buf), stdin))
    return -1;
  *out = atoi(buf);
  return 0;
}

static int select_field(void) {
  int f;
  printf("\n  Field size:\n");
  printf("    0 = GF(2^8)");
  printf("    1 = GF(2^16)\n");
  printf("    2 = GF(2^32)\n");
  read_int("  Select field [0-2]: ", &f);
  if (f < 0 || f > 2) {
    printf("  Invalid field, defaulting to GF(2^8)\n");
    f = 0;
  }
  return f;
}

// Mode 0: Brute Force
static void do_brute_force(fpga_handle_t *h) {
  printf("BRUTE FORCE\n");

  int field = select_field();
  uint32_t mask = field_mask(field);

  uint32_t share_x, share_y, a1, a2;
  read_hex("  Share X (hex): ", &share_x);
  share_x &= mask;
  read_hex("  Share Y (hex): ", &share_y);
  share_y &= mask;
  read_hex("  Coefficient a1: ", &a1);
  a1 &= mask;
  read_hex("  Coefficient a2: ", &a2);
  a2 &= mask;

  printf("\n  Starting brute force on %s...\n", field_name(field));
  printf("  Share: (0x%X, 0x%X), a1=0x%X, a2=0x%X\n", share_x, share_y, a1, a2);

  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);

  fpga_brute_start(h, field, share_x, share_y, a1, a2);
  while (fpga_brute_busy(h)) {
  }

  clock_gettime(CLOCK_MONOTONIC, &t1);
  double elapsed_us =
      (t1.tv_sec - t0.tv_sec) * 1e6 + (t1.tv_nsec - t0.tv_nsec) / 1e3;

  int found;
  uint32_t secret, cycles;
  fpga_brute_result(h, &found, &secret, &cycles);

  printf("\n  Result:\n");
  if (found) {
    printf("    Secret found: 0x%X\n", secret);
  } else {
    printf("    Secret NOT found in search space\n");
  }
  printf("    FPGA cycles:  %u\n", cycles);
  printf("    Wall time:    %.1f us\n", elapsed_us);
}

// Mode 1: Share Generation

static void do_generate_shares(fpga_handle_t *h) {
  printf("SHARE GENERATION\n");

  int field = select_field();
  uint32_t mask = field_mask(field);

  uint32_t secret;
  int k, n;
  read_hex("  Secret (hex): ", &secret);
  secret &= mask;
  read_int("  Threshold k (min shares to reconstruct): ", &k);
  read_int("  Total shares n: ", &n);

  if (k < 2 || k > MAX_SHARES) {
    printf("  Error: k must be 2-%d\n", MAX_SHARES);
    return;
  }
  if (n < k || n > 255) {
    printf("  Error: n must be >= k and <= 255\n");
    return;
  }
  int degree = k - 1;
  if (degree > MAX_DEGREE) {
    printf("  Error: degree %d exceeds max %d\n", degree, MAX_DEGREE);
    return;
  }

  uint32_t coeffs[MAX_DEGREE];
  memset(coeffs, 0, sizeof(coeffs));

  printf("  Generating %d random coefficients...\n", degree);
  for (int i = 0; i < degree; i++) {
    int bytes = (field == FIELD_GF8) ? 1 : (field == FIELD_GF16) ? 2 : 4;
    coeffs[i] = 0;
    if (generate_random_bytes(&coeffs[i], bytes) < 0) {
      printf("  Error: RNG failed\n");
      return;
    }
    coeffs[i] &= mask;

    if (coeffs[i] == 0 && i == degree - 1)
      coeffs[i] = 1;
  }

  printf("\n  Polynomial: f(x) = 0x%X", secret);
  for (int i = 0; i < degree; i++) {
    printf(" + 0x%X*x^%d", coeffs[i], i + 1);
  }
  printf("\n  Field: %s\n\n", field_name(field));

  printf("  %-8s %-12s %-12s\n", "Share", "X", "Y");
  printf("  %-8s %-12s %-12s\n", "-----", "--", "--");

  for (int i = 0; i < n; i++) {
    uint32_t x = (uint32_t)(i + 1);
    uint32_t y = fpga_generate_share(h, field, secret, coeffs, degree, x);
    printf("  %-8d 0x%-10X 0x%-10X\n", i + 1, x, y);
  }

  printf("\n  Done. %d shares generated (k=%d threshold).\n", n, k);
}

// Mode 2: Reconstruction

static void do_reconstruct(fpga_handle_t *h) {
  printf("SECRET RECONSTRUCTION\n");

  int field = select_field();

  int k;
  read_int("  Number of shares to use (k): ", &k);
  if (k < 2 || k > MAX_SHARES) {
    printf("  Error: k must be 2-%d\n", MAX_SHARES);
    return;
  }

  fpga_share_t shares[MAX_SHARES];
  for (int i = 0; i < k; i++) {
    printf("  Share %d:\n", i + 1);
    read_hex("    X (hex): ", &shares[i].x);
    read_hex("    Y (hex): ", &shares[i].y);
  }

  printf("\n  Reconstructing from %d shares on %s...\n", k, field_name(field));

  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);

  uint32_t secret = fpga_reconstruct(h, field, shares, k);

  clock_gettime(CLOCK_MONOTONIC, &t1);
  double elapsed_us =
      (t1.tv_sec - t0.tv_sec) * 1e6 + (t1.tv_nsec - t0.tv_nsec) / 1e3;

  printf("\n  Recovered secret: 0x%X\n", secret);
  printf("  Wall time:        %.1f us\n", elapsed_us);
}

// Full Demo

static void do_demo(fpga_handle_t *h) {
  printf("FULL DEMO\n");

  int field = select_field();
  uint32_t mask = field_mask(field);

  uint32_t secret;
  int k, n;
  read_hex("  Secret (hex): ", &secret);
  secret &= mask;
  read_int("  Threshold k: ", &k);
  read_int("  Total shares n: ", &n);

  if (k < 2 || k > MAX_SHARES || n < k || n > 255) {
    printf("  Error: invalid parameters\n");
    return;
  }
  int degree = k - 1;
  if (degree > MAX_DEGREE) {
    printf("  Error: degree exceeds max\n");
    return;
  }

  uint32_t coeffs[MAX_DEGREE];
  memset(coeffs, 0, sizeof(coeffs));
  for (int i = 0; i < degree; i++) {
    int bytes = (field == FIELD_GF8) ? 1 : (field == FIELD_GF16) ? 2 : 4;
    generate_random_bytes(&coeffs[i], bytes);
    coeffs[i] &= mask;
    if (coeffs[i] == 0 && i == degree - 1)
      coeffs[i] = 1;
  }

  printf("\n  Polynomial: f(x) = 0x%X", secret);
  for (int i = 0; i < degree; i++)
    printf(" + 0x%X*x^%d", coeffs[i], i + 1);
  printf("\n\n");

  printf("  [Step 1] Generating %d shares...\n", n);
  fpga_share_t shares[255];
  for (int i = 0; i < n; i++) {
    shares[i].x = (uint32_t)(i + 1);
    shares[i].y =
        fpga_generate_share(h, field, secret, coeffs, degree, shares[i].x);
    printf("    Share %d: (0x%X, 0x%X)\n", i + 1, shares[i].x, shares[i].y);
  }

  printf("\n  [Step 2] Reconstructing from first %d shares...\n", k);

  struct timespec t0, t1;
  clock_gettime(CLOCK_MONOTONIC, &t0);
  uint32_t recovered = fpga_reconstruct(h, field, shares, k);
  clock_gettime(CLOCK_MONOTONIC, &t1);
  double elapsed_us =
      (t1.tv_sec - t0.tv_sec) * 1e6 + (t1.tv_nsec - t0.tv_nsec) / 1e3;

  printf("\n  Original secret:  0x%X\n", secret);
  printf("  Recovered secret: 0x%X\n", recovered);
  printf("  Match: %s\n", (recovered == secret) ? "YES" : "NO");
  printf("  Reconstruction time: %.1f us\n", elapsed_us);
}

int main(void) {
  printf("  Shamir FPGA Accelerator\n");

  fpga_handle_t *h = fpga_open();
  if (!h) {
    fprintf(stderr, "Error: cannot open FPGA. Run as root.\n");
    return 1;
  }

  fpga_write(h, REG_CONTROL, 0);
  uint32_t ctrl = fpga_read(h, REG_CONTROL);
  uint32_t version = (ctrl >> 24) & 0xFF;
  printf("  HW Version: %u\n\n", version);

  int running = 1;
  while (running) {
    printf("\n--- Menu ---\n");
    printf("  1. Brute Force Attack  (Mode 0)\n");
    printf("  2. Generate Shares     (Mode 1)\n");
    printf("  3. Reconstruct Secret  (Mode 2)\n");
    printf("  4. Full Demo (Gen + Reconstruct)\n");
    printf("  0. Exit\n");

    int choice;
    read_int("Select: ", &choice);

    switch (choice) {
    case 1:
      do_brute_force(h);
      break;
    case 2:
      do_generate_shares(h);
      break;
    case 3:
      do_reconstruct(h);
      break;
    case 4:
      do_demo(h);
      break;
    case 0:
      running = 0;
      break;
    default:
      printf("Invalid choice.\n");
      break;
    }
  }

  fpga_close(h);
  printf("Closed.\n");
  return 0;
}
