# cocotb GHDL simulation of Shamir Accelerator makefile

TOPLEVEL_LANG = vhdl
VHDL_SOURCES = \
    $(PWD)/../rtl/gf_pkg.vhd \
    $(PWD)/../rtl/gf_mult.vhd \
    $(PWD)/../rtl/poly_eval.vhd \
    $(PWD)/../rtl/shamir_recon.vhd \
    $(PWD)/../rtl/brute_pipe.vhd \
    $(PWD)/../rtl/brute_array.vhd \
    $(PWD)/../rtl/brute_ctrl.vhd \
    $(PWD)/../rtl/brute_force.vhd \
    $(PWD)/../rtl/avalon_regs.vhd \
    $(PWD)/../rtl/top_shamir.vhd

TOPLEVEL = top_shamir
MODULE = test_shamir

SIM = ghdl

# GHDL-specific options(used 93 since lite doenst have 08 support),
# well the testbench can be written in 08 if you only use ghdl and not through quartus I believe
EXTRA_ARGS = --std=93
GHDL_ARGS = --std=93

SIM_ARGS = --vcd=shamir.vcd

include $(shell cocotb-config --makefiles)/Makefile.sim
