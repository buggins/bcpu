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
	iiiii   immediate offset (signed), 10/12/18 bits
	mmm     immediate value mode for Rb operand of ALU, MUL, or BUS operation
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


In assembler code, append period sign and condition code after instruction mnemonic to specify condition.

If no condition suffix specified for instruction, cccc=0000 (unconditional execution) is assumed.

	JMP     label     ; unconditional jump to label 
	JMP.LE  label     ; jump to label if result of signed comparision is less or equal
	MOV     R1, R5    ; R1 := R5  unconditionally
	MOV.NE  R2, R7    ; R2 := R7  if Z flag == 0


Address modes
-------------

Two address modes are supported for LOAD, STORE and JUMPs:

	Rb + offset12     relative to general purpose register
	PC + offset18     relative to Program Counter register

Jumps and calls
---------------

There is only single instruction covering all calls, jumps, returns, both conditional and unconditional.

	31                                    0    Instruction type
	cccc 110 0 dddddd bbbbbb ii iiiiii iiii    CALL   Rd, Rb+offset12
	cccc 110 1 dddddd iiiiii ii iiiiii iiii    CALL   Rd, PC+offset18

Instruction field ddddd (Rd) is register to save return address to.
When R0 is specified in dddddd field, return address is not saved, and CALL instruction turns into JUMP.

Assembler will implement JMP and RET instructions as aliases to CALL

	CALL  R63, label1     ; store return address in R63 and jump to label1
	JMP   label2          ; jump to label2
	RET   R63             ; return to address stored in Rb

Immediate value encoding
------------------------

As second operand B for ALU, MUL, BUS instructions, instead of general purpose register 
value Rb it's possible to specify constant index from immediate constants table.

Bit field mmm specifies type of operand B.

* When mmm==000, bit field bbbbbb is an index of general purpose register Rb
* When mmm!=000, concatenated mmm and bbbbbb fields form 9-bit index in constant table

Content of constant table may be defined as core configuration.

First 64 entries of immediate table are not accessible due to selected instruction encoding, so only 512-64=448 constants are available.


ALU operations
--------------

BCPU32 ALU instructions have 3-address format.

ALU takes two operands (Ra - from register, Rb_or_imm - from register or immediate constant table), and stores result of operation in register Rd.

	ADD R1, R2, R3     ;   R1:=R2+R3, update flags C,Z,S,V
	SBC R1, R2, R3     ;   R1:=R2-R3-C, update flags C,Z,S,V
	ADD R5, R6, 256    ;   R5:=R6 & 256, update flag Z

Flags are being updated depending on type of operation.


	oooo   mnemonic    flags    description                 comment
	0000   ADDNF       ....     Rd := Ra + Rb_or_imm        add, no flags update
	0001   SUBNF       ....     Rd := Ra - Rb_or_imm        subtract, no flags update
	0010   ADD         VSZC     Rd := Ra + Rb_or_imm        add
	0011   ADC         VSZC     Rd := Ra + Rb_or_imm + C    add with carry
	0100   SUB         VSZC     Rd := Ra - Rb_or_imm        subtract
	0101   SBC         VSZC     Rd := Ra - Rb_or_imm - C    subtract with borrow
	0110   RSUB        VSZC     Rd := Rb_or_imm - Ra        subtract with reversed operands
	0111   RSBC        VSZC     Rd := Rb_or_imm - Ra - C    subtract with reversed operands with borrow
	1000   AND         ..Z.     Rd := Ra & Rb_or_imm        and
	1001   ANDN        ..Z.     Rd := Ra & ~Rb_or_imm       and with inverted operand B (reset bits)
	1010   OR          ..Z.     Rd := Ra | Rb_or_imm        or
	1011   XOR         ..Z.     Rd := Ra ^ Rb_or_imm        exclusive or
	1100   -           ....     reserved                    reserved for future usage
	1101   -           ....     reserved                    reserved for future usage
	1110   -           ....     reserved                    reserved for future usage
	1111   -           ....     reserved                    reserved for future usage

Useful aliases:

	NOP                ADDNF R0, R0, R0          no operation
	MOV Rd, Ra         ADDNF Rd, Ra, R0          Rd := Ra
	INC Rd, Ra         ADDNF Rd, Ra, 1           Rd := Ra + 1
	DEC Rd, Ra         SUBNF Rd, Ra, 1           Rd := Ra - 1
	CMP Ra, Rb         SUB   R0, Ra, Rb          (Ra - Rb), set flags according to comparision result

