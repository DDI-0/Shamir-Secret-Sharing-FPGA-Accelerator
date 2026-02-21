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

