/**
 * fpga_analysis.c - FPGA hardware analysis with real metrics
 */
#define _POSIX_C_SOURCE 200112L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdint.h>

#include "fpga_driver.h"
#include "gf.h"
#include "shamir.h"

static struct timespec ts_start, ts_end;

static void timer_start(void) {
    clock_gettime(CLOCK_MONOTONIC, &ts_start);
}

static double timer_us(void) {
    clock_gettime(CLOCK_MONOTONIC, &ts_end);
    return (ts_end.tv_sec - ts_start.tv_sec) * 1e6 + 
           (ts_end.tv_nsec - ts_start.tv_nsec) / 1e3;
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    
    fpga_handle_t *h = fpga_open();
    if (!h) {
        printf("ERROR: Cannot open FPGA\n");
        return 1;
    }
    gf_init();

    /* MODE 0: BRUTE FORCE */
    printf("\n=== MODE 0: BRUTE FORCE ===\n");
    {
        struct { int field; uint32_t secret; uint32_t a1; } tests[] = {
            {FIELD_GF8,  0x00, 0x05},
            {FIELD_GF8,  0x42, 0x05},
            {FIELD_GF8,  0xFF, 0x05},
            {FIELD_GF16, 0x0000, 0x05},
            {FIELD_GF16, 0x00FF, 0x05},
            {FIELD_GF16, 0x0FFF, 0x05},
            {FIELD_GF32, 0x00, 0x05},
            {FIELD_GF32, 0x10, 0x05},
            {FIELD_GF32, 0xFF, 0x05},
        };
        
        for (int i = 0; i < 9; i++) {
            gf_field_t gf = (tests[i].field == FIELD_GF8) ? GF_8 :
                            (tests[i].field == FIELD_GF16) ? GF_16 : GF_32;
            uint32_t y = gf_add(tests[i].secret, gf_mult(tests[i].a1, 1, gf));
            
            timer_start();
            fpga_brute_start(h, tests[i].field, 1, y, tests[i].a1);
            while (fpga_brute_busy(h)) {}
            double us = timer_us();
            
            int found; uint32_t result, cycles;
            fpga_brute_result(h, &found, &result, &cycles);
            
            printf("field=%d secret=0x%04X cycles=%u time=%.1fus result=0x%04X %s\n",
                   tests[i].field, tests[i].secret, cycles, us, result,
                   (found && result == tests[i].secret) ? "PASS" : "FAIL");
        }
    }

    /*  MODE 1: SHARE GENERATION  */
    printf("\n=== MODE 1: SHARE GENERATION ===\n");
    {
        struct { int field; uint32_t secret; uint32_t a1; uint32_t x; } tests[] = {
            {FIELD_GF8,  0x42, 0x05, 1},
            {FIELD_GF8,  0x42, 0x05, 5},
            {FIELD_GF16, 0xDEAD, 0x0033, 1},
            {FIELD_GF16, 0xDEAD, 0x0033, 3},
            {FIELD_GF32, 0xCAFEBABE, 0x1234, 1},
        };
        
        for (int i = 0; i < 5; i++) {
            gf_field_t gf = (tests[i].field == FIELD_GF8) ? GF_8 :
                            (tests[i].field == FIELD_GF16) ? GF_16 : GF_32;
            uint32_t coeffs[] = {tests[i].a1};
            
            timer_start();
            uint32_t hw = fpga_generate_share(h, tests[i].field, tests[i].secret, coeffs, 1, tests[i].x);
            double us = timer_us();
            
            uint32_t sw = gf_add(tests[i].secret, gf_mult(tests[i].a1, tests[i].x, gf));
            
            printf("field=%d secret=0x%X a1=0x%X x=%u hw=0x%X sw=0x%X time=%.1fus %s\n",
                   tests[i].field, tests[i].secret, tests[i].a1, tests[i].x,
                   hw, sw, us, (hw == sw) ? "PASS" : "FAIL");
        }
    }

    /*  MODE 2: RECONSTRUCTION  */
    printf("\n=== MODE 2: RECONSTRUCTION ===\n");
    {
        fpga_share_t s2[] = {{1, 0x47}, {2, 0x48}};
        fpga_share_t s3[] = {{1, 0x47}, {2, 0x48}, {3, 0x4D}};
        
        timer_start();
        uint32_t r2 = fpga_reconstruct(h, FIELD_GF8, s2, 2);
        double t2 = timer_us();
        
        timer_start();
        uint32_t r3 = fpga_reconstruct(h, FIELD_GF8, s3, 3);
        double t3 = timer_us();
        
        printf("k=2 expected=0x42 hw=0x%02X time=%.1fus %s\n", r2, t2, (r2==0x42)?"PASS":"FAIL");
        printf("k=3 expected=0x42 hw=0x%02X time=%.1fus %s\n", r3, t3, (r3==0x42)?"PASS":"FAIL");
    }
   
    fpga_close(h);
    return 0;
}
