BCPU16 Instruction Set Architecture
===================================

BCPU16 is 16-bit RISC architecture optimized for FPGA implementation.


General Purpose Registers
-------------------------

Each thread of BCPU16 has 8 16-bit general purpose registers R0..R7

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

All instructions have the same length, 16 bits.


	15                  0    Instruction type
	0 oooo bbb aaa ddd mm    ALU Rd, Ra, Rb_or_imm
	1 0000 ddd aaa iii ii    BUSRD   Rd, Ra, imm5
	1 0001 ddd aaa iii ii    BUSWAIT Rd, Ra, imm5
	1 0010 bbb aaa iii ii    BUSWR   Rb, Ra, imm5
	1 0011 bbb aaa iii ii    BUSWRI  Rb, Ra, imm5
	1 0100 ddd aaa iii ii    LOAD Rd, Ra+imm5
	1 0101 bbb aaa iii ii    STORE Rb, Ra+imm5
	1 0110 ddd iii iii ii    LOAD Rd, PC+imm8
	1 0111 bbb iii iii ii    STORE Rb, PC+imm8
	1 100 cccc aaa iii ii    JMP.cond Ra+imm5
	1 101 cccc iii iii ii    JMP.cond PC+imm8
	1 110 iiii iii iii ii    CALL PC+imm12
	1 111 iiii iii iii ii    JMP  PC+imm12

Instruction bit fields:

	cccc    condition code
	aaa     general purpose register index Ra (R0..R7) to read
	bbb     general purpose register index Rb (R0..R7) to read
	ddd     destination general purpose register index Rd (R0..R7) to write result of operation to (R0==ignore)
	iiiii   immediate offset (signed), 5/8/12 bits
	mm      immediate value mode for Rb operand of ALU and MUL operation
	oooo    ALU or multiplier operation code


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

BCPU16 address space is 16-bit word based. There are no instructions to access single bytes.

Two address modes are supported for LOAD, STORE and conditional JUMPs:

	Rb + offset5     relative to General Purpose Register
	PC + offset8     relative to Program Counter Register

For JMP and CALL:

	PC + offset12    relative to Program Counter Register

Offset values are signed. E.g. for offset5, range is -16..+15



Jumps and calls
---------------

	15                  0    Instruction type
	1 100 cccc aaa iii ii    JMP.cond Ra+imm5
	1 101 cccc iii iii ii    JMP.cond PC+imm8
	1 110 iiii iii iii ii    CALL PC+imm12
	1 111 iiii iii iii ii    JMP  PC+imm12

Conditional jumps support Ra+imm5 and PC+imm8 modes. General purpose register mode allows long jumps (load address to register + jump) and conditional returns.

Unconditional call and jump support only PC+imm12 mode.

CALL instruction stores return address in R7 (link register).


Immediate value encoding
------------------------

As second operand B for ALU and MUL instructions, instead of general purpose register 
value Rb it's possible to specify constant index from immediate constants table.

Bit field mmm specifies type of operand B.

	mm bbb    Rb_or_imm value
	00 000    R0 register value
	00 001    R1 register value
	00 010    R2 register value
	00 011    R3 register value
	00 100    R4 register value
	00 101    R5 register value
	00 110    R6 register value
	00 111    R7 register value
	01 000    3  useful constant
	01 001    5  useful constant
	01 010    6  useful constant
	01 011    7  useful constant
	01 100    15 useful constant
	01 101    0x00FF useful mask constant
	01 110    0xFF00 useful mask constant
	01 111    0xFFFF useful mask constant
	10 000    0b0000000000000001 (2^0)
	10 001    0b0000000000000010 (2^1)
	10 010    0b0000000000000100 (2^2)
	10 011    0b0000000000001000 (2^3)
	10 100    0b0000000000010000 (2^4)
	10 101    0b0000000000100000 (2^5)
	10 110    0b0000000001000000 (2^6)
	10 111    0b0000000010000000 (2^7)
	11 000    0b0000000100000000 (2^8)
	11 001    0b0000001000000000 (2^9)
	11 010    0b0000010000000000 (2^10)
	11 011    0b0000100000000000 (2^11)
	11 100    0b0001000000000000 (2^12)
	11 101    0b0010000000000000 (2^13)
	11 110    0b0100000000000000 (2^14)
	11 111    0b1000000000000000 (2^15)


ALU operations
--------------

BCPU16 ALU instructions have 3-address format.

	15                  0    Instruction type
	0 oooo bbb aaa ddd mm    ALU Rd, Ra, Rb_or_imm


ALU takes two operands (Ra - from register, Rb_or_imm - from register or immediate constant table), and stores result of operation in register Rd.

	ADD R1, R2, R3     ;   R1:=R2+R3, update flags C,Z,S,V
	SBC R1, R2, R3     ;   R1:=R2-R3-C, update flags C,Z,S,V
	ADD R5, R6, 256    ;   R5:=R6 & 256, update flag Z

Flags are being updated depending on type of operation.


	oooo   mnemonic  flags  description                 comment
	0000   ADDNF     ....   Rd := Ra + Rb_or_imm        add, no flags update
	0001   SUBNF     ....   Rd := Ra - Rb_or_imm        subtract, no flags update
	0010   ADD       VSZC   Rd := Ra + Rb_or_imm        add
	0011   ADC       VSZC   Rd := Ra + Rb_or_imm + C    add with carry
	0100   SUB       VSZC   Rd := Ra - Rb_or_imm        subtract
	0101   SBC       VSZC   Rd := Ra - Rb_or_imm - C    subtract with borrow
	0110   RSUB      VSZC   Rd := Rb_or_imm - Ra        subtract with reversed operands
	0111   RSBC      VSZC   Rd := Rb_or_imm - Ra - C    subtract with reversed operands with borrow
	1000   AND       ..Z.   Rd := Ra & Rb_or_imm        and
	1001   ANDN      ..Z.   Rd := Ra & ~Rb_or_imm       and with inverted operand B (reset bits)
	1010   OR        ..Z.   Rd := Ra | Rb_or_imm        or
	1011   XOR       ..Z.   Rd := Ra ^ Rb_or_imm        exclusive or
	1100   MUL       ....   Rd := (Ra * Rb_or_imm)     multiply, get lower 16 bits of result
	1101   MULHSU    ....   Rd := (Ra * Rb_or_imm)>>16 multiply signed * unsigned, take higher 16 bits of result
	1110   MULHUU    ....   Rd := (Ra * Rb_or_imm)>>16 multiply unsigned * unsigned, take higher 16 bits of result
	1111   MULHSS    ....   Rd := (Ra * Rb_or_imm)>>16 multiply signed * signed, take higher 16 bits of result


Useful aliases:

	NOP              ADDNF R0, R0, R0    no operation
	MOV  Rd, Ra      ADDNF Rd, Ra, R0    Rd := Ra
	INC  Rd, Ra      ADDNF Rd, Ra, 1     Rd := Ra + 1
	DEC  Rd, Ra      SUBNF Rd, Ra, 1     Rd := Ra - 1
	CMP  Ra, Rb      SUB   R0, Ra, Rb    (Ra - Rb), set flags according to comparision result
	CMPC Ra, Rb      SUB   R0, Ra, Rb    (Ra - Rb), set flags according to comparision result
	TEST Ra, Rb      AND   R0, Ra, Rb    (Ra & Rb), set flags according to result

