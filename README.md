# Shamir Secret Sharing — FPGA Accelerator

Hardware-accelerated Shamir's Secret Sharing on the **DE10-Standard** (Cyclone V SoC). The FPGA fabric handles GF(2^n) arithmetic for share generation, secret reconstruction, and brute-force key recovery, while the HPS ARM core runs the control software.

## Features

| Mode | Operation | Description |
|------|-----------|-------------|
| 0 | **Brute Force** | Parallel search over GF(2^n) with 16 pipelines (degree-2 polynomials) |
| 1 | **Share Generation** | Horner's method polynomial evaluation |
| 2 | **Reconstruction** | Lagrange interpolation at x = 0 |

- **Supported fields:** GF(2⁸), GF(2¹⁶), GF(2³²)
- **Threshold:** k = 3 (brute force), k = 2–32 (reconstruction)

## Architecture

```
HPS ARM Core                        FPGA Fabric
┌─────────────┐    Avalon-MM    ┌──────────────────────┐
│  C Driver    │◄──────────────►│  avalon_regs.vhd     │
│  (fpga_demo) │                │    ├─ poly_eval       │
└─────────────┘                │    ├─ shamir_recon    │
                                │    └─ brute_force     │
                                │         └─ 16 pipes   │
                                └──────────────────────┘
```

### RTL Modules

| Module | Function |
|--------|----------|
| `top_shamir.vhd` | Top-level mode multiplexer |
| `avalon_regs.vhd` | Avalon-MM register interface |
| `brute_force.vhd` | 16-pipeline parallel brute-force search |
| `brute_pipe.vhd` | Single brute-force pipeline stage |
| `poly_eval.vhd` | Horner's method polynomial evaluator |
| `shamir_recon.vhd` | Lagrange interpolation reconstructor |
| `gf_pkg.vhd` | GF(2⁸), GF(2¹⁶), GF(2³²) arithmetic |

## Build & Run

```bash
# Cross-compile for ARM HPS
cd sw
make cross

# Copy to board
scp build/shamir root@<board-ip>:/root/

# Run on DE10
./shamir
```

## FPGA Resource Usage

| Resource | Used | Available | % |
|----------|------|-----------|---|
| ALMs | 13,209 | 41,910 | 32% |
| Registers | 6,165 | — | — |
| Block RAM | 0 | 5,662,720 bits | 0% |
| DSP Blocks | 0 | 112 | 0% |

## Results

### Reconstruction (Mode 2)

All tests pass — reconstructed secret matches original across varying thresholds.

| # | Secret | Field | k | n | Recovered | Match | Time (μs) |
|---|--------|-------|---|---|-----------|-------|-----------|
| 1 | `0x04C11DB7` | GF(2³²) | 3 | 5 | `0x04C11DB7` | 8.6 |
| 2 | `0x04C11DB7` | GF(2³²) | 5 | 13 | `0x04C11DB7` | 12.6 |
| 3 | `0x1EDC6F41` | GF(2³²) | 6 | 10 | `0x1EDC6F41` | 13.8 |
| 4 | `0x741B8CD7` | GF(2³²) | 7 | 10 | `0x741B8CD7` | 15.8 |
| 5 | `0x41445335` | GF(2³²) | 7 | 9 | `0x41445335` | 15.9 |

### Brute Force Attack (Mode 0)

16 parallel pipelines searching over GF(2^n) for degree-2 polynomials. The FPGA sustains ~114 M attempts/sec at 50 MHz with ~2.29 effective attempts per clock cycle.

| Secret | Field | a1 | a2 | Share | Cycles | Wall Time | Throughput |
|--------|-------|----|----|-------|--------|-----------|------------|
| `0x04C11DB7` | GF(2³²) | `0x9FB6981C` | `0x1AEC0D63` | (0x4, 0xD4DBAA60) | 34.9M | 0.70 s | 114.3 M/s |
| `0x1EDC6F41` | GF(2³²) | `0xABC677E1` | `0xA1486351` | (0x2, 0xCC710C50) | 226.5M | 4.53 s | 114.3 M/s |
| `0x741B8CD7` | GF(2³²) | `0x4513927D` | `0x546D1CE3` | (0x5, 0x37FA87B9) | 852.2M | 17.04 s | 114.3 M/s |
| `0x41445335` | GF(2³²) | `0x1CB37B39` | `0x0` | (0x3, 0x6491DE7E) | 479.1M | 9.58 s | 114.3 M/s |
| `0x3D65` | GF(2¹⁶) | `0x9B1F` | `0x0` | (0x3, 0x804F) | 6.9K | 0.14 ms | 110.1 M/s |
| `0xA001` | GF(2¹⁶) | `0x1F60` | `0xFF3C` | (0x5, 0x3E74) | 17.9K | 0.36 ms | 112.6 M/s |

**Key metrics (GF(2³²) @ 50 MHz):**
- **Throughput:** ~114.3 million attempts/sec
- **Cycles per attempt:** ~0.4375 (2.29 attempts/cycle)
- **Full search space (2³²):** ~37.6 seconds

## Directory Structure

```
├── hw/
│   ├── rtl/            # VHDL source files
│   └── tb/             # Testbenches (GHDL + cocotb)
├── sw/
│   ├── src/            # C driver and CLI
│   ├── include/        # Headers
│   └── Makefile
├── SoC_Shamir.qsys     # Platform Designer system
└── DE10_Standard.qsf    # Quartus project
```
<img width="942" height="1016" alt="image" src="https://github.com/user-attachments/assets/a7da537c-92fc-425b-ab93-c9d5dea0ec89" />


