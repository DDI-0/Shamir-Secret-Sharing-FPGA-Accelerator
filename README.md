# Shamir Secret Sharing FPGA Accelerator

Hardware-accelerated Shamir's Secret Sharing on DE10-Standard (Cyclone V SoC).

## Features

- **Mode 0**: Brute-force attack with 100 parallel pipelines
- **Mode 1**: Share generation (Horner's polynomial evaluation)
- **Mode 2**: Secret reconstruction (Lagrange interpolation)
- **Fields**: GF(2^8), GF(2^16), GF(2^32)

## Build

```bash
make cross                    # this generates the arm binary files to be sent over ssh to the HPS
```

## Usage

```bash
# Test hardware
./fpga_demo test-regs

# Brute force
./fpga_demo brute8 0x47 0x05
./fpga_demo brute32 0x12345688 0x12345678


# Generate share
./fpga_demo generate 16 0xDEAD 0x05 3
./fpga_demo generate 32 0xDEADBEEF 0x12345678 2

# Reconstruct
./fpga_demo reconstruct 16 1:0xDEA8 2:0xDEAF
./fpga_demo reconstruct 16 1:<y1> 2:<y2>

# Run analysis
./fpga_analysis
```

## Hardware

| Module | Function |
|--------|----------|
| `top_shamir.vhd` | Top-level mode multiplexer |
| `brute_force.vhd` | 100-pipeline parallel search |
| `poly_eval.vhd` | Horner's method |
| `shamir_recon.vhd` | Lagrange interpolation |
| `gf_pkg.vhd` | GF(2^n) arithmetic |

## Resources (Quartus)

- ALMs: 27,091 / 41,910 (65%)
- Registers: 1,551
- Block RAM: 0%
- DSP: 0%

## Results

```
Mode 0 (Brute): worked with meterics
Mode 1 (Gen):   worked with meterics(added a timeout on the sw actual calculation is faster)
Mode 2 (Recon): WIP - timing sync needed
```
