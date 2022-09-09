/**
    BCPU16 : 16-bit barrel MCU project.
    Author: Vadim Lopatin, 2021
    License: LGPL v2
    Language: System Verilog
    Compatibility: universal
    Resources: 2 LUTs on Xilinx Series 7 FPGA

    Module bcpu_cond_eval contains condition evaluation: takes flags and condition code, returns 0 if condition is false, 1 if condition is true
    
*/

`include "bcpu_cond_defs.vh"

module bcpu_cond_eval
(
    // input flag values {V,S,Z,C}
    input wire [3:0] FLAGS_IN,
    // condition code, 0000 is unconditional
    input wire [3:0] CONDITION_CODE,
    
    // 1 if condition is met
    output wire CONDITION_RESULT
);

assign CONDITION_RESULT 
   = (CONDITION_CODE==`COND_NONE) ? 1'b1      // 0000 jmp  1                 unconditional
   : (CONDITION_CODE==`COND_NC) ? ~FLAGS_IN[`FLAG_C] // 0001 jnc  c = 0
   : (CONDITION_CODE==`COND_NZ) ? ~FLAGS_IN[`FLAG_Z] // 0010 jnz  z = 0             jne
   : (CONDITION_CODE==`COND_Z)  ?  FLAGS_IN[`FLAG_Z]  // 0011 jz   z = 1             je

   : (CONDITION_CODE==`COND_NS) ? ~FLAGS_IN[`FLAG_S] // 0100 jns  s = 0
   : (CONDITION_CODE==`COND_S)  ?  FLAGS_IN[`FLAG_S] // 0101 js   s = 1
   : (CONDITION_CODE==`COND_NO) ? ~FLAGS_IN[`FLAG_V] // 0100 jno  v = 0
   : (CONDITION_CODE==`COND_O)  ?  FLAGS_IN[`FLAG_V] // 0101 jo   v = 1

   : (CONDITION_CODE==`COND_A)  ? (~FLAGS_IN[`FLAG_C] & ~FLAGS_IN[`FLAG_Z])    // 1000 ja   c = 0 & z = 0     above (unsigned compare)            !jbe
   : (CONDITION_CODE==`COND_AE) ? (~FLAGS_IN[`FLAG_C] & FLAGS_IN[`FLAG_Z])     // 1001 jae  c = 0 | z = 1     above or equal (unsigned compare)
   : (CONDITION_CODE==`COND_B)  ?   FLAGS_IN[`FLAG_C]                          // 1010 jb   c = 1             below (unsigned compare)            jc
   : (CONDITION_CODE==`COND_BE) ?  (FLAGS_IN[`FLAG_C] | FLAGS_IN[`FLAG_Z])      // 1011 jbe  c = 1 | z = 1     below or equal (unsigned compare)   !ja

   : (CONDITION_CODE==`COND_L)  ? (FLAGS_IN[`FLAG_V] != FLAGS_IN[`FLAG_S])                     // 1100 jl   v != s            less (signed compare)
   : (CONDITION_CODE==`COND_LE) ? (FLAGS_IN[`FLAG_V] != FLAGS_IN[`FLAG_S]) | FLAGS_IN[`FLAG_Z]  // 1101 jle  v != s | z = 1    less or equal (signed compare)      !jg
   : (CONDITION_CODE==`COND_G)  ? (FLAGS_IN[`FLAG_V] == FLAGS_IN[`FLAG_S]) & ~FLAGS_IN[`FLAG_Z] // 1110 jg   v = s & z = 0     greater (signed compare)            !jle
   :                              (FLAGS_IN[`FLAG_V] == FLAGS_IN[`FLAG_S]) | FLAGS_IN[`FLAG_Z];  // 1111 jge  v = s | z = 1     less or equal (signed compare)


endmodule
