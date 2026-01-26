"""
test_shamir.py - Cocotb Testbench for Multi-Mode Shamir Accelerator
Tests: Brute-Force (Mode 0), Share Generation (Mode 1), Reconstruction (Mode 2)
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Register addresses (word addresses)
REG_CONTROL   = 0   # 0x00
REG_STATUS    = 1   # 0x04
REG_FIELD     = 2   # 0x08
REG_SHARE_X0  = 3   # 0x0C
REG_SHARE_Y0  = 4   # 0x10
REG_COEFF0    = 5   # 0x14
REG_RESULT    = 6   # 0x18
REG_CYCLES    = 7   # 0x1C
REG_SHARE_X1  = 8   # 0x20
REG_SHARE_Y1  = 9   # 0x24
REG_SHARE_X2  = 10  # 0x28
REG_SHARE_Y2  = 11  # 0x2C
REG_SHARE_X3  = 12  # 0x30
REG_SHARE_Y3  = 13  # 0x34
REG_COEFF1    = 14  # 0x38
REG_COEFF2    = 15  # 0x3C
REG_COEFF3    = 16  # 0x40
REG_K_DEGREE  = 17  # 0x44
REG_EVAL_X    = 18  # 0x48

# Control register bits
CTRL_START    = 0x01
CTRL_ABORT    = 0x02
CTRL_INT_CLR  = 0x04
CTRL_INT_EN   = 0x08
CTRL_MODE_SHIFT = 4

# Status register bits
STAT_BUSY     = 0x01
STAT_FOUND    = 0x02
STAT_DONE     = 0x04
STAT_INT_PEND = 0x08

# Mode values
MODE_BRUTE      = 0
MODE_GENERATE   = 1
MODE_RECONSTRUCT = 2

# Field values
FIELD_GF8   = 0
FIELD_GF16  = 1
FIELD_GF32  = 2


class AvalonMM:
    """Simple Avalon-MM agent for Shamir accelerator"""
    
    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.clk
        self.reset_n = dut.reset_n
        self.address = dut.avs_address
        self.read = dut.avs_read
        self.readdata = dut.avs_readdata
        self.write = dut.avs_write
        self.writedata = dut.avs_writedata
        self.irq = dut.irq

        # Start 100 MHz clock (10 ns period)
        cocotb.start_soon(Clock(self.clk, 10, units="ns").start())

    async def reset(self):
        self.reset_n.value = 0
        self.read.value = 0
        self.write.value = 0
        await Timer(50, units="ns")
        self.reset_n.value = 1
        await Timer(20, units="ns")

    async def write_reg(self, addr: int, data: int):
        self.address.value = addr
        self.writedata.value = data
        self.write.value = 1
        self.read.value = 0
        await RisingEdge(self.clk)
        self.write.value = 0
        await RisingEdge(self.clk)

    async def read_reg(self, addr: int) -> int:
        self.address.value = addr
        self.read.value = 1
        self.write.value = 0
        await RisingEdge(self.clk)
        self.read.value = 0
        await RisingEdge(self.clk)
        return self.readdata.value.integer

    async def wait_done(self, timeout_cycles: int = 10000) -> bool:
        """Wait for operation to complete (BUSY=0 or DONE=1)"""
        for _ in range(timeout_cycles):
            status = await self.read_reg(REG_STATUS)
            if (status & STAT_DONE) or not (status & STAT_BUSY):
                return True
            await RisingEdge(self.clk)
        return False


@cocotb.test()
async def test_brute_force_gf8(dut):
    """Test Mode 0: Brute-Force Attack (GF8)"""
    avmm = AvalonMM(dut)
    await avmm.reset()

    dut._log.info("=== Test: Brute Force (Mode 0, GF8) ===")
    
    # Check version
    ctrl = await avmm.read_reg(REG_CONTROL)
    version = (ctrl >> 24) & 0xFF
    dut._log.info(f"Control register: 0x{ctrl:08X} (version {version})")
    assert version == 2, f"Expected version 2, got {version}"

    # Configure: GF8, share (1, 0x47), coeff a1=0x05
    # Expected secret: 0x42 (since 0x42 XOR 0x05 = 0x47)
    await avmm.write_reg(REG_FIELD, FIELD_GF8)
    await avmm.write_reg(REG_SHARE_X0, 1)
    await avmm.write_reg(REG_SHARE_Y0, 0x47)
    await avmm.write_reg(REG_COEFF0, 0x05)

    # Start brute force (mode 0)
    await avmm.write_reg(REG_CONTROL, (MODE_BRUTE << CTRL_MODE_SHIFT) | CTRL_START)
    
    dut._log.info("Brute force started, waiting...")
    
    # Wait for completion
    done = await avmm.wait_done()
    assert done, "Brute force timed out!"
    
    # Read result
    status = await avmm.read_reg(REG_STATUS)
    result = await avmm.read_reg(REG_RESULT)
    cycles = await avmm.read_reg(REG_CYCLES)
    
    found = bool(status & STAT_FOUND)
    dut._log.info(f"Status: 0x{status:02X}, Found: {found}, Result: 0x{result:02X}, Cycles: {cycles}")
    
    assert found, "Secret not found!"
    assert result == 0x42, f"Expected 0x42, got 0x{result:02X}"
    
    dut._log.info("Brute force test PASSED!")


@cocotb.test()
async def test_share_generation_gf8(dut):
    """Test Mode 1: Share Generation (GF8)"""
    avmm = AvalonMM(dut)
    await avmm.reset()

    dut._log.info("=== Test: Share Generation (Mode 1, GF8) ===")
    
    # f(x) = 0x42 + 0x05*x, evaluate at x=1
    # Expected: f(1) = 0x42 XOR 0x05 = 0x47
    await avmm.write_reg(REG_FIELD, FIELD_GF8)
    await avmm.write_reg(REG_COEFF0, 0x42)    # a0 = secret
    await avmm.write_reg(REG_COEFF1, 0x05)    # a1
    await avmm.write_reg(REG_K_DEGREE, 1)      # degree = 1
    await avmm.write_reg(REG_EVAL_X, 1)        # x = 1

    # Start share generation (mode 1)
    await avmm.write_reg(REG_CONTROL, (MODE_GENERATE << CTRL_MODE_SHIFT) | CTRL_START)
    
    dut._log.info("Share generation started, waiting...")
    
    # Wait for completion
    done = await avmm.wait_done()
    assert done, "Share generation timed out!"
    
    # Read result
    result = await avmm.read_reg(REG_RESULT)
    dut._log.info(f"f(1) = 0x{result:02X}")
    
    assert result == 0x47, f"Expected 0x47, got 0x{result:02X}"
    
    dut._log.info("Share generation test PASSED!")


@cocotb.test()
async def test_share_generation_x2(dut):
    """Test Mode 1: Share Generation at x=2 (GF8)"""
    avmm = AvalonMM(dut)
    await avmm.reset()

    dut._log.info("=== Test: Share Generation at x=2 (GF8) ===")
    
    # f(x) = 0x42 + 0x05*x, evaluate at x=2
    # In GF(2^8): 0x05 * 2 = 0x0A, so f(2) = 0x42 XOR 0x0A = 0x48
    await avmm.write_reg(REG_FIELD, FIELD_GF8)
    await avmm.write_reg(REG_COEFF0, 0x42)
    await avmm.write_reg(REG_COEFF1, 0x05)
    await avmm.write_reg(REG_K_DEGREE, 1)
    await avmm.write_reg(REG_EVAL_X, 2)

    await avmm.write_reg(REG_CONTROL, (MODE_GENERATE << CTRL_MODE_SHIFT) | CTRL_START)
    
    done = await avmm.wait_done()
    assert done, "Share generation timed out!"
    
    result = await avmm.read_reg(REG_RESULT)
    dut._log.info(f"f(2) = 0x{result:02X}")
    
    assert result == 0x48, f"Expected 0x48, got 0x{result:02X}"
    
    dut._log.info("Share generation x=2 test PASSED!")


@cocotb.test()
async def test_reconstruction_gf8(dut):
    """Test Mode 2: Secret Reconstruction (GF8)"""
    avmm = AvalonMM(dut)
    await avmm.reset()

    dut._log.info("=== Test: Reconstruction (Mode 2, GF8) ===")
    
    # Shares from f(x) = 0x42 + 0x05*x:
    # (1, 0x47), (2, 0x48)
    # Expected secret: 0x42
    await avmm.write_reg(REG_FIELD, FIELD_GF8)
    await avmm.write_reg(REG_SHARE_X0, 1)
    await avmm.write_reg(REG_SHARE_Y0, 0x47)
    await avmm.write_reg(REG_SHARE_X1, 2)
    await avmm.write_reg(REG_SHARE_Y1, 0x48)
    await avmm.write_reg(REG_K_DEGREE, 2)  # k = 2 shares

    # Start reconstruction (mode 2)
    await avmm.write_reg(REG_CONTROL, (MODE_RECONSTRUCT << CTRL_MODE_SHIFT) | CTRL_START)
    
    dut._log.info("Reconstruction started, waiting...")
    
    done = await avmm.wait_done()
    assert done, "Reconstruction timed out!"
    
    result = await avmm.read_reg(REG_RESULT)
    dut._log.info(f"Reconstructed secret: 0x{result:02X}")
    
    assert result == 0x42, f"Expected 0x42, got 0x{result:02X}"
    
    dut._log.info("Reconstruction test PASSED!")


@cocotb.test()
async def test_gf16_share_generation(dut):
    """Test Mode 1: Share Generation (GF16)"""
    avmm = AvalonMM(dut)
    await avmm.reset()

    dut._log.info("=== Test: Share Generation (Mode 1, GF16) ===")
    
    # f(x) = 0xABCD + 0x1234*x, evaluate at x=1
    # Expected: f(1) = 0xABCD XOR 0x1234 = 0xB9F9
    await avmm.write_reg(REG_FIELD, FIELD_GF16)
    await avmm.write_reg(REG_COEFF0, 0xABCD)
    await avmm.write_reg(REG_COEFF1, 0x1234)
    await avmm.write_reg(REG_K_DEGREE, 1)
    await avmm.write_reg(REG_EVAL_X, 1)

    await avmm.write_reg(REG_CONTROL, (MODE_GENERATE << CTRL_MODE_SHIFT) | CTRL_START)
    
    done = await avmm.wait_done()
    assert done, "GF16 share generation timed out!"
    
    result = await avmm.read_reg(REG_RESULT)
    dut._log.info(f"f(1) = 0x{result:04X}")
    
    assert result == 0xB9F9, f"Expected 0xB9F9, got 0x{result:04X}"
    
    dut._log.info("GF16 share generation test PASSED!")


@cocotb.test()
async def test_interrupt(dut):
    """Test interrupt functionality"""
    avmm = AvalonMM(dut)
    await avmm.reset()

    dut._log.info("=== Test: Interrupt ===")
    
    # Configure simple share generation with interrupt enabled
    await avmm.write_reg(REG_FIELD, FIELD_GF8)
    await avmm.write_reg(REG_COEFF0, 0x42)
    await avmm.write_reg(REG_COEFF1, 0x05)
    await avmm.write_reg(REG_K_DEGREE, 1)
    await avmm.write_reg(REG_EVAL_X, 1)

    # Start with interrupt enabled
    await avmm.write_reg(REG_CONTROL, (MODE_GENERATE << CTRL_MODE_SHIFT) | CTRL_START | CTRL_INT_EN)
    
    # Wait for IRQ
    for _ in range(100):
        await RisingEdge(avmm.clk)
        if avmm.irq.value == 1:
            break
    
    irq_asserted = (avmm.irq.value == 1)
    dut._log.info(f"IRQ asserted: {irq_asserted}")
    
    # Check status shows interrupt pending
    status = await avmm.read_reg(REG_STATUS)
    int_pending = bool(status & STAT_INT_PEND)
    dut._log.info(f"Interrupt pending: {int_pending}")
    
    # Clear interrupt
    await avmm.write_reg(REG_CONTROL, CTRL_INT_CLR)
    await RisingEdge(avmm.clk)
    await RisingEdge(avmm.clk)
    
    irq_cleared = (avmm.irq.value == 0)
    dut._log.info(f"IRQ cleared: {irq_cleared}")
    
    assert irq_asserted, "IRQ was not asserted!"
    assert irq_cleared, "IRQ was not cleared!"
    
    dut._log.info("Interrupt test PASSED!")


@cocotb.test()
async def test_all_modes_roundtrip(dut):
    """Full roundtrip: Generate shares, then reconstruct"""
    avmm = AvalonMM(dut)
    await avmm.reset()

    dut._log.info("=== Test: Full Roundtrip ===")
    
    secret = 0x42
    a1 = 0x05
    
    # Generate share at x=1
    await avmm.write_reg(REG_FIELD, FIELD_GF8)
    await avmm.write_reg(REG_COEFF0, secret)
    await avmm.write_reg(REG_COEFF1, a1)
    await avmm.write_reg(REG_K_DEGREE, 1)
    await avmm.write_reg(REG_EVAL_X, 1)
    await avmm.write_reg(REG_CONTROL, (MODE_GENERATE << CTRL_MODE_SHIFT) | CTRL_START)
    await avmm.wait_done()
    y1 = await avmm.read_reg(REG_RESULT)
    dut._log.info(f"Generated share (1, 0x{y1:02X})")
    
    # Generate share at x=2
    await avmm.write_reg(REG_EVAL_X, 2)
    await avmm.write_reg(REG_CONTROL, (MODE_GENERATE << CTRL_MODE_SHIFT) | CTRL_START)
    await avmm.wait_done()
    y2 = await avmm.read_reg(REG_RESULT)
    dut._log.info(f"Generated share (2, 0x{y2:02X})")
    
    # Reconstruct from shares
    await avmm.write_reg(REG_SHARE_X0, 1)
    await avmm.write_reg(REG_SHARE_Y0, y1)
    await avmm.write_reg(REG_SHARE_X1, 2)
    await avmm.write_reg(REG_SHARE_Y1, y2)
    await avmm.write_reg(REG_K_DEGREE, 2)
    await avmm.write_reg(REG_CONTROL, (MODE_RECONSTRUCT << CTRL_MODE_SHIFT) | CTRL_START)
    await avmm.wait_done()
    
    recovered = await avmm.read_reg(REG_RESULT)
    dut._log.info(f"Recovered secret: 0x{recovered:02X}")
    
    assert recovered == secret, f"Expected 0x{secret:02X}, got 0x{recovered:02X}"
    
    dut._log.info("Full roundtrip test PASSED!")
