BCPU32 Instruction Set Architecture
===================================

BCPU32 is 32-bit RISC architecture optimized for FPGA implementation.


General Purpose Registers
-------------------------

Each thread of BCPU32 has 64 32-bit general purpose registers R0..R63
Register R0 is constant 0, writes to R0 are ignored

Program Counter
---------------

Register PC is program counter.
Number of bits is configurable, depends on supported memory size.


Flags
-----

BCPU32 has 4 flags:

	C    carry (for arithmetic)
	Z    zero result
	S    result sign
	V    arithmetic overflow

Instruction format
------------------

All instructions have the same length, 32 bits.


	31                                    0    Instruction type
	cccc 000 m aaaaaa bbbbbb mm dddddd oooo    ALU    Rd, Ra, Rb_or_imm
	cccc 001 m aaaaaa bbbbbb mm dddddd oooo    MUL    Rd, Ra, Rb_or_imm
	cccc 010 m dddddd bbbbbb mm iiiiii iiii    BUSRD  Rd, Rb_or_imm, addr10
	cccc 011 m aaaaaa bbbbbb mm iiiiii iiii    BUSWR  Ra, Rb_or_imm, addr10
	cccc 100 0 dddddd bbbbbb ii iiiiii iiii    LOAD   Rd, Rb+offset12
	cccc 100 1 dddddd iiiiii ii iiiiii iiii    LOAD   Rd, PC+offset18
	cccc 101 0 aaaaaa bbbbbb ii iiiiii iiii    STORE  Ra, Rb+offset12
	cccc 101 1 aaaaaa iiiiii ii iiiiii iiii    STORE  Ra, PC+offset18
	cccc 110 0 dddddd bbbbbb ii iiiiii iiii    CALL   Rd, Rb+offset12
	cccc 110 1 dddddd iiiiii ii iiiiii iiii    CALL   Rd, PC+offset18
	cccc 111 x xxxxxx xxxxxx xx xxxxxx xxxx    RESERVED

Instruction bit fields:

	cccc    condition code
	aaaaaa  general purpose register index Ra (R0..R63) to read
	bbbbbb  general purpose register index Rb (R0..R63) to read
	dddddd  destination general purpose register index Rd (R0..R63) to write result of operation to (R0==ignore)
	iiiii   immediate offset
	mmm     immediate value mode for Rb operand of ALU, MUL, or BUS operation


Condition codes
---------------

Each instruction is prefixed with condition code (cccc instruction bit field).
Based on condition and flag values, any instruction may be skipped.


	cccc  code        flags           description
	0000  -           unconditional   always true
	0001  NC          C==0            carry is not set
	0010  NZ, NE      Z==0            not equal, non-zero result
	0011  Z, E        Z==1            equal, zero result
	0100  NS          S==0            positive result
	0101  S           S==1            negative result
	0110  NO          V==0            no arithmetic overflow
	0111  O           V==1            arithmetic overflow
	1000  A           C==0 & Z==0     above, > for unsigned
	1001  AE          C==0 | Z==1     above or equal, >= for unsigned
	1010  B, C        C==1            below, < for unsigned
	1011  BE          C==1 | Z==1     below or equal, <= for unsigned
	1100  L           V!=S            less, < for signed
	1101  LE          V!=S | Z==1     less or equal, <= for signed
	1110  G           V==S & Z==0     greater, > for signed
	1111  GE          V==S | Z==1     greter or equal, >= for signed

Address modes
-------------

Two address modes are supported for LOAD, STORE and JUMPs:

	Rb + offset12     relative to general purpose register
	PC + offset18     relative to Program Counter register


Immediate value encoding
------------------------

As second operand B for ALU, MUL, BUS instructions, instead of general purpose register 
value Rb it's possible to specify constant index from immediate constants table.

Bit field mmm specifies type of operand B.
When mmm==000, bit field bbbbbb is an index of general purpose register Rb.
When mmm!=000, concatenated mmm and bbbbbb fields form 9-bit index in constant table.
Content of constant table may be defined as core configuration.

First 64 entries of immediate table are not accessible due to selected instruction encoding, so only 512-64=448 constants are available.

