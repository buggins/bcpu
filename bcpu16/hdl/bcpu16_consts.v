`timescale 1ns / 1ps

/**
    BCPU16 : 16-bit barrel MCU project.
    Author: Vadim Lopatin, 2021
    License: LGPL v2
    Language: System Verilog
    Compatibility: universal
    Resources: 16 x LUT6 on Xilinx Series 7 FPGA

    Module bcpu_consts implements optional replacement of B operand register with once of 24 constants.
    
16 of 24 constants contain single bit set, the rest 8 contain several other useful values.

| mm | bbb | B operand value     |  Description                    |
|----|-----|---------------------|---------------------------------|
| 00 | 000 | R0                  |  Register R0 value (constant 0) |
| 00 | 001 | R1                  |  Register R1 value              |
| 00 | 010 | R2                  |  Register R2 value              |
| 00 | 011 | R3                  |  Register R3 value              |
| 00 | 100 | R4                  |  Register R4 value              |
| 00 | 101 | R5                  |  Register R5 value              |
| 00 | 110 | R6                  |  Register R6 value              |
| 00 | 111 | R7                  |  Register R7 value              |
| 01 | 000 | 0000_0000_0000_0011 |  3                              |
| 01 | 001 | 0000_0000_0000_0101 |  5                              |
| 01 | 010 | 0000_0000_0000_0110 |  6                              |
| 01 | 011 | 0000_0000_0000_0111 |  7                              |
| 01 | 100 | 0000_0000_0000_1111 |  15                             |
| 01 | 101 | 0000_0000_1111_1111 |  0x00FF (lower byte mask)       |
| 01 | 110 | 1111_1111_0000_0000 |  0xFF00 (higher byte mask)      |
| 01 | 111 | 1111_1111_1111_1111 |  0xFFFF (-1, all bits set)      |
| 10 | 000 | 0000_0000_0000_0001 |  1 (bit 0 mask)                 |
| 10 | 001 | 0000_0000_0000_0010 |  2 (bit 1 mask)                 |
| 10 | 010 | 0000_0000_0000_0100 |  4 (bit 2 mask)                 |
| 10 | 011 | 0000_0000_0000_1000 |  8 (bit 3 mask)                 |
| 10 | 100 | 0000_0000_0001_0000 |  16 (bit 4 mask)                |
| 10 | 101 | 0000_0000_0010_0000 |  32 (bit 5 mask)                |
| 10 | 110 | 0000_0000_0100_0000 |  64 (bit 6 mask)                |
| 10 | 111 | 0000_0000_1000_0000 |  128 (bit 7 mask)               |
| 11 | 000 | 0000_0001_0000_0000 |  256 (bit 8 mask)               |
| 11 | 001 | 0000_0010_0000_0000 |  512 (bit 9 mask)               |
| 11 | 010 | 0000_0100_0000_0000 |  1024 (bit 10 mask)             |
| 11 | 011 | 0000_1000_0000_0000 |  2048 (bit 11 mask)             |
| 11 | 100 | 0001_0000_0000_0000 |  4096 (bit 12 mask)             |
| 11 | 101 | 0010_0000_0000_0000 |  8192 (bit 13 mask)             |
| 11 | 110 | 0100_0000_0000_0000 |  16384 (bit 14 mask)            |
| 11 | 111 | 1000_0000_0000_0000 |  32768 (bit 15 mask)            |
    
*/

module bcpu16_consts
#(
    parameter DATA_WIDTH = 16
)
(
    // input register value
    input wire [DATA_WIDTH - 1 : 0] B_VALUE_IN,

    // bbb: B register index from instruction - used as const index when CONST_MODE==1 
    input wire [2:0] B_REG_INDEX, 

    // mm: const_mode - when 00 return B_VALUE_IN, when 01,10,11 return one of 24 consts from table 
    input wire [1:0] CONST_MODE,

    // output value: CONST_MODE?(1<<B_REG_INDEX):B_VALUE_IN    
    output wire [DATA_WIDTH - 1 : 0] B_VALUE_OUT
);

wire [4:0] index;
assign index = {CONST_MODE, B_REG_INDEX};

assign B_VALUE_OUT 
    = (CONST_MODE == 2'b00) ? B_VALUE_IN              // mode 00: pass register value as is to output
    // mode 01:
    // small constants (non-power of 2)
    : (index == 5'b01_000) ? 16'b00000000_00000011  // 3
    : (index == 5'b01_001) ? 16'b00000000_00000101 // 5
    : (index == 5'b01_010) ? 16'b00000000_00000110  // 6
    : (index == 5'b01_011) ? 16'b00000000_00000111  // 7
    // useful masks
    : (index == 5'b01_100) ? 16'b00000000_00001111  // 15
    : (index == 5'b01_101) ? 16'b00000000_11111111  // 255
    : (index == 5'b01_110) ? 16'b11111111_00000000  // 0xff00
    // all bits set (-1)
    : (index == 5'b01_111) ? 16'b11111111_11111111  // 0xffff
    // mode 10, 11: single bit set (powers of 2)
    : (index == 5'b10_000) ? 16'b00000000_00000001  // 1<<0
    : (index == 5'b10_001) ? 16'b00000000_00000010  // 1<<1
    : (index == 5'b10_010) ? 16'b00000000_00000100  // 1<<2
    : (index == 5'b10_011) ? 16'b00000000_00001000  // 1<<3
    : (index == 5'b10_100) ? 16'b00000000_00010000  // 1<<4
    : (index == 5'b10_101) ? 16'b00000000_00100000  // 1<<5
    : (index == 5'b10_110) ? 16'b00000000_01000000  // 1<<6
    : (index == 5'b10_111) ? 16'b00000000_10000000  // 1<<7
    : (index == 5'b11_000) ? 16'b00000001_00000000  // 1<<8
    : (index == 5'b11_001) ? 16'b00000010_00000000  // 1<<9
    : (index == 5'b11_010) ? 16'b00000100_00000000  // 1<<10
    : (index == 5'b11_011) ? 16'b00001000_00000000  // 1<<11
    : (index == 5'b11_100) ? 16'b00010000_00000000  // 1<<12
    : (index == 5'b11_101) ? 16'b00100000_00000000  // 1<<13
    : (index == 5'b11_110) ? 16'b01000000_00000000  // 1<<14
    :                        16'b10000000_00000000;  // 1<<15

endmodule
