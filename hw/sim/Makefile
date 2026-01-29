# Makefile for VHDL simulation with GHDL

GHDL = ghdl
GHDLFLAGS = --std=08

RTL_DIR = ../rtl
TB_DIR = ../tb

# RTL sources 
RTL_SRCS = $(RTL_DIR)/gf_pkg.vhd \
           $(RTL_DIR)/gf_mult.vhd \
           $(RTL_DIR)/poly_eval.vhd \
           $(RTL_DIR)/lagrange_3pt.vhd \
           $(RTL_DIR)/addr_extract.vhd \
           $(RTL_DIR)/shamir_recon.vhd \
           $(RTL_DIR)/brute_pipe.vhd \
           $(RTL_DIR)/brute_array.vhd \
           $(RTL_DIR)/brute_ctrl.vhd \
           $(RTL_DIR)/brute_force.vhd \
           $(RTL_DIR)/avalon_regs.vhd \
           $(RTL_DIR)/top_shamir.vhd

# Testbenches
TB_SRCS = $(TB_DIR)/tb_gf_mult.vhd \
          $(TB_DIR)/tb_addr_extract.vhd \
          $(TB_DIR)/tb_brute_force.vhd \
          $(TB_DIR)/tb_top_shamir.vhd

.PHONY: all analyze sim_gf_mult sim_addr sim_brute sim_top sim_all clean

all: analyze

analyze:
	$(GHDL) -a $(GHDLFLAGS) $(RTL_SRCS)
	$(GHDL) -a $(GHDLFLAGS) $(TB_SRCS)
	@echo "Analysis complete"

sim_gf_mult: analyze
	$(GHDL) -e $(GHDLFLAGS) tb_gf_mult
	$(GHDL) -r $(GHDLFLAGS) tb_gf_mult --stop-time=500ns --wave=gf_mult.ghw

sim_addr: analyze
	$(GHDL) -e $(GHDLFLAGS) tb_addr_extract
	$(GHDL) -r $(GHDLFLAGS) tb_addr_extract --stop-time=100ns

sim_brute: analyze
	$(GHDL) -e $(GHDLFLAGS) tb_brute_force
	$(GHDL) -r $(GHDLFLAGS) tb_brute_force --stop-time=50us --wave=brute_force.ghw

sim_top: analyze
	$(GHDL) -e $(GHDLFLAGS) tb_top_shamir
	$(GHDL) -r $(GHDLFLAGS) tb_top_shamir --stop-time=100us --wave=top_shamir.ghw

sim_all: sim_gf_mult sim_addr sim_brute sim_top
	@echo "All simulations complete"

clean:
	rm -f *.o *.cf *.ghw work-obj*.cf
	@echo "Cleaned"

# Help
help:
	@echo "VHDL Simulation Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  analyze       - Analyze all VHDL sources"
	@echo "  sim_gf_mult   - Simulate GF multiplier"
	@echo "  sim_addr      - Simulate address extraction"
	@echo "  sim_all       - Run all simulations"
	@echo "  clean         - Remove generated files"
