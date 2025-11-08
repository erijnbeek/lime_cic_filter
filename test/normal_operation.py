# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge
import os
import matplotlib.pyplot as plt
import numpy as np

debugging = False

async def apply_bitstream(dut):
    """Apply the bitstream to the DUT"""
    
    # Read test bitstream
    bitstream_file = os.path.join(os.path.dirname(__file__), "test_bitstream.txt")
    with open(bitstream_file, 'r') as f:
        bitstream = [int(line.strip()) for line in f if line.strip()]
    
    # Data capture arrays
    captured_data = []
    prev_uio7 = 0

    # Apply bitstream to first bit of ui_in on falling edge of clock
    for i, bit_value in enumerate(bitstream):
        # Wait for falling edge of clock
        await FallingEdge(dut.clk)
        
        # Set the first bit of ui_in to the bitstream value
        current_ui_in = int(dut.ui_in.value)
        # Clear bit 0 and set it to bit_value
        new_ui_in = (current_ui_in & 0xFE) | bit_value
        dut.ui_in.value = new_ui_in
        
        # Capture uo_out data on uio[7] rising edge
        current_uio7 = int(dut.uio_out.value) & 1
        
        if not prev_uio7 and current_uio7:
            data = int(dut.uo_out.value) * 2 **7 + int(dut.uio_out.value) // 2
            if debugging: 
                dut._log.info(data)
            captured_data.append(data)
        prev_uio7 = current_uio7
    
    return captured_data



async def run_test_sequence(dut):
    """Run the main test sequence"""
    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Apply bitstream and capture data
    captured_data = await apply_bitstream(dut)
        
    # Simple FFT analysis test of captured data
    dut._log.info(f"Performing FFT on {len(captured_data)} samples")
    data_array = np.array(captured_data, dtype=float)
    fft_result = np.fft.fft(data_array)
    fft_magnitude = np.abs(fft_result)
    
    if debugging:
        dut._log.info(f"FFT Magnitude: {fft_magnitude}")
    
    # Check if forth bin (index 3) is the highest, excluding bin 1 (DC)
    assert np.argmax(fft_magnitude[1:]) == 2
    # Check if third bin (index 3) is significantly higher than the rest
    assert fft_magnitude[3] > np.sum(fft_magnitude[1:20]) - fft_magnitude[3]
    dut._log.info("FFT analysis passed")
    
    # Create and save plot
    if debugging:
        dut._log.info(f"Creating plot with {len(captured_data)} samples")
        
        plt.figure(figsize=(12, 6))
        plt.plot(captured_data, 'b-', linewidth=1)
        plt.xlabel('Sample Number')
        plt.ylabel('uo_out Value')
        plt.title(f'CIC Filter Output Data ({len(captured_data)} samples on uio[7] rising edges)')
        plt.grid(True, alpha=0.3)
        
        # Save plot as PNG
        plot_file = os.path.join(os.path.dirname(__file__), "cic_output_plot.png")
        plt.savefig(plot_file, dpi=300, bbox_inches='tight')
        plt.close()
        
        dut._log.info(f"Plot saved as {plot_file}")

def set_debug_mode(dut, mode: int):
    """Set the debug mode for the DUT"""
    # Set the first bit of ui_in to the bitstream value
    current_ui_in = int(dut.ui_in.value)
    # Clear bit 0 and set it to bit_value
    dut.ui_in.value = (current_ui_in & 0x0F) | (mode * 0x10)

@cocotb.test()
async def normal_operation(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # First order CIC filter test ui_in[1] = 0
    dut.ui_in.value = 0
    await run_test_sequence(dut)
    
    # Second order CIC filter test ui_in[1] = 1
    dut.ui_in.value = 2
    await run_test_sequence(dut)

    
    dut._log.info("Debug mode tests cic1")
    dut.ui_in.value = 4
    dut.uio_in.value = 0xB4
    await ClockCycles(dut.clk, 1)
    for debug_mode in range(16):
        set_debug_mode(dut, debug_mode)
        await apply_bitstream(dut)
        match debug_mode:
            case 4:
                assert dut.uo_out.value == 0xB4
            

    dut._log.info("Debug mode tests cic2")
    dut.ui_in.value = 2
    await ClockCycles(dut.clk, 1)
    for debug_mode in range(16):
        set_debug_mode(dut, debug_mode)
        await apply_bitstream(dut)
