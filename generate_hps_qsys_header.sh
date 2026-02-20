#!/bin/sh
export PATH="$PATH:/cygdrive/c/intelFPGA_lite/23.1std/quartus/sopc_builder/bin"

sopc-create-header-files \
"./SoC_Shamir.sopcinfo" \
--single hps_0.h \
--module hps_0
