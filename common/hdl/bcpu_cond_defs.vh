// flag indexes
`define FLAG_C 0
`define FLAG_Z 1
`define FLAG_S 2
`define FLAG_V 3



// condition codes for conditional jumps
// jmp  1                 unconditional
`define COND_NONE 4'b0000
// jnc  c = 0             for C==1 test, use JB code
`define COND_NC   4'b0001
// jnz  z = 0             jne                                        !=
`define COND_NZ   4'b0010
// jz   z = 1             je                                         ==
`define COND_Z    4'b0011
// jns  s = 0
`define COND_NS   4'b0100
// js   s = 1
`define COND_S    4'b0101
// jno  v = 0
`define COND_NO   4'b0110
// jo   v = 1
`define COND_O    4'b0111
// ja   c = 0 & z = 0     above (unsigned compare)            !jbe    >
`define COND_A    4'b1000
// jae  c = 0 | z = 1     above or equal (unsigned compare)           >=
`define COND_AE   4'b1001
// jb   c = 1             below (unsigned compare)            jc      <
`define COND_B    4'b1010
// jbe  c = 1 | z = 1     below or equal (unsigned compare)   !ja     <=
`define COND_BE   4'b1011
// jl   v != s            less (signed compare)                       <
`define COND_L    4'b1100
// jle  v != s | z = 1    less or equal (signed compare)      !jg     <=
`define COND_LE   4'b1101
// jg   v = s & z = 0     greater (signed compare)            !jle    >
`define COND_G    4'b1110
// jge  v = s | z = 1     less or equal (signed compare)              >=
`define COND_GE   4'b1111

