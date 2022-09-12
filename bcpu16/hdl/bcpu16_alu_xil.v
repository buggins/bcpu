`include "bcpu16_defs.vh"

module bcpu16_alu_xil
#(
    parameter DATA_WIDTH=16,
    parameter ADDR_WIDTH=12
)
(
    input wire CLK,
    input wire RESET,
    input wire CE,
    input wire ALU_EN,
    input wire CALL_EN,
    input wire MEM_RD_EN,
    input wire BUS_RD_EN,
    input wire [3:0] ALU_OP,
    input wire [3:0] FLAGS_IN,
    input wire [DATA_WIDTH-1:0] A_IN,
    input wire [DATA_WIDTH-1:0] B_IN,

    input wire [ADDR_WIDTH-1:0] PC_IN,
    input wire [DATA_WIDTH-1:0] MEM_RD_DATA,
    input wire [DATA_WIDTH-1:0] BUS_RD_DATA,

    output wire [DATA_WIDTH-1:0] ALU_OUT,
    output wire [3:0] FLAGS_OUT

    , output wire[47:0] debug_dsp_p_out
//    , output wire[47:0] debug_dsp_p_out_1

);

wire   a_sign; // A sign extension for bit 16
assign a_sign = ~A_IN[DATA_WIDTH-1]     ? 1'b0      // input is not negative
              : (ALU_OP==`ALUOP_MUL)    ? 1'b0
              : (ALU_OP==`ALUOP_MULHUU) ? 1'b0
              : (ALU_OP==`ALUOP_MULHSU) ? 1'b1
              : (ALU_OP==`ALUOP_MULHSS) ? 1'b1
              :                           1'b1;
wire   a_sign_upper;  // A sign extemsion for bits 17+
assign a_sign_upper = (ALU_OP[3:2] == 2'b11) & a_sign; // can be non-zero for multiplu only
              
wire   b_sign; // B sign extension for bit 16
assign b_sign = ~B_IN[DATA_WIDTH-1]     ? 1'b0      // input is not negative 
              : (ALU_OP==`ALUOP_MUL)    ? 1'b0
              : (ALU_OP==`ALUOP_MULHUU) ? 1'b0
              : (ALU_OP==`ALUOP_MULHSU) ? 1'b0
              : (ALU_OP==`ALUOP_MULHSS) ? 1'b1
              :                           1'b1;     // arithmetic and logic: signed
wire   b_sign_upper; // B sign extemsion for bits 17+
assign b_sign_upper = (ALU_OP[3:2] == 2'b11) & b_sign; // can be non-zero for multiplu only

// data inputs
wire [29:0] dsp_a_in; // 30-bit A data input
wire [17:0] dsp_b_in; // 18-bit B data input

assign dsp_b_in = {
         b_sign_upper,   // [17]
         b_sign,         // [16]
         B_IN            // [15:0]
     };
assign dsp_a_in = {
         {30-25{1'b0}},         // for mult, only 25 bits from A are used, so pad with 0s
         {25-17{a_sign_upper}}, // [24:17]
         a_sign,                // [16]
         A_IN                   // [15:0]
     };
// C reg will have A_IN value delayed by 1 cycle since its pipeline has length 1
reg  [15:0] a_in_1;   // delay A_IN by 1 clock cycle - to feed C port of DSP
wire [47:0] dsp_c_in; // 48-bit C data input
assign dsp_c_in = { {48-17{1'b0}},           // padding to 48 bits with 0s 
                    a_in_1[DATA_WIDTH-1],    // sign extension - for overflow detection
                    a_in_1                   // 16 bits of A_IN delayed by 1 cycle
                  };
                   
// delay A_IN by 1 cycle
always @(posedge CLK)
    if (RESET)   
        a_in_1 <= 0;
    else if (CE & (is_alu_op | CALL_EN)) 
        a_in_1 <= CALL_EN ? PC_IN   // PC for call  
                :           A_IN;  // A  for ALU ops

reg [3:0] alu_op_1;
always @(posedge CLK)
    if (RESET)
        alu_op_1 <= 0;
    else if (CE)
        alu_op_1 <= ALU_OP;


wire is_mul_op;
assign is_mul_op = ALU_EN 
                   & (ALU_OP[3:2] == 2'b11)
                   & CE;
reg is_mul_op_1;
always @(posedge CLK) if (RESET) is_mul_op_1 <= 0; else if (CE) is_mul_op_1 <= is_mul_op; 
                   
wire is_alu_op;
assign is_alu_op = ALU_EN 
                   & (ALU_OP[3:2] != 2'b11)  // exclude mult 
                   //& (ALU_OP[3:1] != 3'b001)  ignore bus ops
                   & CE;
reg is_alu_op_1;
always @(posedge CLK) if (RESET) is_alu_op_1 <= 0; else if (CE) is_alu_op_1 <= is_alu_op; 

wire alu_en;
assign alu_en = ALU_EN & CE;

reg alu_en_1;
always @(posedge CLK) if (RESET) alu_en_1 <= 0; else if (CE) alu_en_1 <= alu_en; 

//reg alu_en_2;
//always @(posedge CLK) if (RESET) alu_en_2 <= 0; else if (CE) alu_en_2 <= alu_en_1; 

`define RESULT_MUX_LOW  2'b00
`define RESULT_MUX_HIGH 2'b01
`define RESULT_MUX_MEM  2'b10
`define RESULT_MUX_BUS  2'b11

reg call_en_1;
always @(posedge CLK) if (RESET) call_en_1 <= 0; else if (CE) call_en_1 <= CALL_EN; 


reg bus_rd_en_1;
reg mem_rd_en_1;
always @(posedge CLK)
    if (RESET) begin
        bus_rd_en_1 <= 0;
        mem_rd_en_1 <= 0;
    end else if (CE) begin
        bus_rd_en_1 <= BUS_RD_EN;
        mem_rd_en_1 <= MEM_RD_EN;
    end


wire [1:0] result_mux;
assign result_mux  = bus_rd_en_1                            ? `RESULT_MUX_BUS
                   : mem_rd_en_1                            ? `RESULT_MUX_MEM
                   : call_en_1                              ? `RESULT_MUX_LOW
                   : ((alu_op_1 == `ALUOP_MULHUU) // ALU_EN &  
                    | (alu_op_1 == `ALUOP_MULHSU) 
                    | (alu_op_1 == `ALUOP_MULHSS))          ? `RESULT_MUX_HIGH
                   :                                          `RESULT_MUX_LOW;

reg [1:0] result_mux_2;
reg [1:0] result_mux_3;
always @(posedge CLK)
    if (RESET) begin
        result_mux_2 <= 0;
        result_mux_3 <= 0;
    end else if (CE) begin
        result_mux_2 <= result_mux;
        result_mux_3 <= result_mux_2;
    end

reg [DATA_WIDTH-1:0] mem_data_3;
always @(posedge CLK) if (RESET) mem_data_3 <= 0; else if ((result_mux_2 == `RESULT_MUX_MEM) & CE) mem_data_3 <= MEM_RD_DATA;
reg [DATA_WIDTH-1:0] bus_data_3;
always @(posedge CLK) if (RESET) bus_data_3 <= 0; else if ((result_mux_2 == `RESULT_MUX_BUS) & CE) bus_data_3 <= BUS_RD_DATA;


//==========================================
// FLAGS pipeline
//==========================================

reg [3:0] flags1;
reg [3:0] flags2;
reg [3:0] flags3;
reg [3:0] flagsmask1;
reg [3:0] flagsmask2;
reg [3:0] flagsmask3;
wire [3:0] new_flags;

always @(posedge CLK) begin
    if (RESET) begin
        flags3 <= 0;
        flags2 <= 0;
        flags1 <= 0;
        flagsmask2 <= 0;
        flagsmask3 <= 0;
    end else if (CE) begin
        flagsmask3 <= flagsmask2;
        flagsmask2 <= ~alu_en_1                  ? 4'b0000
                    : (alu_op_1 == `ALUOP_ADD)   ? 4'b1111
                    : (alu_op_1 == `ALUOP_SUB)   ? 4'b1111
                    : (alu_op_1 == `ALUOP_ADC)   ? 4'b1111
                    : (alu_op_1 == `ALUOP_SBC)   ? 4'b1111
                    : (alu_op_1 == `ALUOP_AND)   ? 4'b0110
                    : (alu_op_1 == `ALUOP_ANDN)  ? 4'b0110
                    : (alu_op_1 == `ALUOP_OR)    ? 4'b0110
                    : (alu_op_1 == `ALUOP_XOR)   ? 4'b0110
                    :                              4'b0000;
        flags3 <= flags2;
        flags2 <= flags1;
        flags1 <= FLAGS_IN;
    end
end

wire [3:0] flags_out;
assign flags_out = (new_flags & flagsmask3) | (flags3 & ~flagsmask3);
assign FLAGS_OUT = flags_out;


// carry input
wire dsp_carry_in;

//wire [24:0] dsp_d_in; // 25-bit D data input
// data output
wire [47:0] dsp_p_out; // 48-bit P data output

wire dsp_patterndetect;          // 1-bit output: Pattern detect output   (1 when P[31:0] == 32'b0)
wire dsp_patternbdetect;         // 1-bit output: Pattern detect output   (1 when P[31:0] == 32'h3ffff)

//wire dsp_overflow;
//wire dsp_underflow;

// mode
wire[3:0] dsp_alumode;               // 4-bit input: ALU control input
wire[2:0] dsp_carryinsel;            // 3-bit input: Carry select input
wire[4:0] dsp_inmode;                // 5-bit input: INMODE control input
wire[6:0] dsp_opmode;                // 7-bit input: Operation mode input

// Z=C Y=0 X=A:B
`define DSP_OPMODE_NORMAL   7'b011_00_11 
// Z=C Y=0 X=A:B
`define DSP_OPMODE_OR_ANDN  7'b011_10_11 
// Z=C Y=0 X=0
`define DSP_OPMODE_C        7'b011_00_00
// Z=0 Y=M X=M
`define DSP_OPMODE_MUL      7'b000_01_01 


// Z + X + Y + CARRYIN
`define DSP_ALU_MODE_ADD   4'b0000
// Z - (X + Y + CARRYIN)
`define DSP_ALU_MODE_SUB   4'b0011
// -Z + (X + Y + CARRYIN) - 1
//`define DSP_ALU_MODE_RSUB  4'b0001
// Z AND X
`define DSP_ALU_MODE_AND  4'b1100
// Z XOR X
`define DSP_ALU_MODE_XOR  4'b0100
// Z OR X  -- reqiores OPMODE[3:2]=2'b10
`define DSP_ALU_MODE_OR   4'b1100
// Z AND (NOT X)  -- reqiores OPMODE[3:2]=2'b10
`define DSP_ALU_MODE_ANDN   4'b1111

//} dsp_inmode_t;
assign dsp_inmode = 5'b1_0001; // B1 A1
assign dsp_carryinsel = 3'b000;  // CARRYIN 
assign dsp_opmode = (call_en_1)                                            ? `DSP_OPMODE_C
                  : (is_mul_op_1)                                          ? `DSP_OPMODE_MUL
                  : alu_en_1 & ((alu_op_1 == `ALUOP_OR) 
                             || (alu_op_1 == `ALUOP_ANDN)) 
                                                                           ? `DSP_OPMODE_OR_ANDN 
                  :                                                          `DSP_OPMODE_NORMAL;

assign dsp_alumode = call_en_1                 ? `DSP_ALU_MODE_ADD            // for CALL ret addr - pass C to out
                   : (alu_op_1 == `ALUOP_OR)   ? `DSP_ALU_MODE_OR
                   : (alu_op_1 == `ALUOP_XOR)  ? `DSP_ALU_MODE_XOR
                   : (alu_op_1 == `ALUOP_AND)  ? `DSP_ALU_MODE_AND
                   : (alu_op_1 == `ALUOP_ANDN) ? `DSP_ALU_MODE_ANDN
                   : (alu_op_1 == `ALUOP_DEC)  ? `DSP_ALU_MODE_SUB
                   : (alu_op_1 == `ALUOP_SUB)  ? `DSP_ALU_MODE_SUB
                   : (alu_op_1 == `ALUOP_SBC)  ? `DSP_ALU_MODE_SUB
                   : (alu_op_1 == `ALUOP_BUSWR)? `DSP_ALU_MODE_SUB        // just for optimization op[0]==1 for sub
                   :                             `DSP_ALU_MODE_ADD;
                   
assign dsp_carry_in = (alu_en_1 && (alu_op_1 == `ALUOP_ADC))  ? flags1[`FLAG_C]
                    : (alu_en_1 && (alu_op_1 == `ALUOP_SBC))  ? flags1[`FLAG_C]
                    :                                           0;

assign new_flags[`FLAG_C] = dsp_p_out[DATA_WIDTH+1];
assign new_flags[`FLAG_Z] = dsp_patterndetect;
assign new_flags[`FLAG_S] = dsp_p_out[DATA_WIDTH-1];
assign new_flags[`FLAG_V] = dsp_p_out[DATA_WIDTH-1] != dsp_p_out[DATA_WIDTH];


// 1 to reset DSP
wire dsp_reset;
assign dsp_reset = RESET;

// DSP48E1: 48-bit Multi-Functional Arithmetic Block
//          Artix-7
// Xilinx HDL Language Template, version 2017.3

DSP48E1 #(
    // Feature Control Attributes: Data Path Selection
    .A_INPUT("DIRECT"),               // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
    .B_INPUT("DIRECT"),               // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
    .USE_DPORT("FALSE"),              // Select D port usage (TRUE or FALSE)
    .USE_MULT("DYNAMIC"),             // Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
    .USE_SIMD("ONE48"),               // SIMD selection ("ONE48", "TWO24", "FOUR12")
    // Pattern Detector Attributes: Pattern Detection Configuration
    .AUTORESET_PATDET("NO_RESET"),    // "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH" 
    .MASK(48'hffffffff0000),          // 48-bit mask value for pattern detect (1=ignore)
    .PATTERN(48'h000000000000),       // 48-bit pattern match for pattern detect
    .SEL_MASK("MASK"),                // "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2" 
    .SEL_PATTERN("PATTERN"),          // Select pattern value ("PATTERN" or "C")
    .USE_PATTERN_DETECT("PATDET"),    // Enable pattern detect ("PATDET" or "NO_PATDET")
    // Register Control Attributes: Pipeline Register Configuration
    .ACASCREG(2),                     // Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
    .ADREG(1),                        // Number of pipeline stages for pre-adder (0 or 1)
    .ALUMODEREG(1),                   // Number of pipeline stages for ALUMODE (0 or 1)
    .AREG(2),                         // Number of pipeline stages for A (0, 1 or 2)
    .BCASCREG(2),                     // Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
    .BREG(2),                         // Number of pipeline stages for B (0, 1 or 2)
    .CARRYINREG(1),                   // Number of pipeline stages for CARRYIN (0 or 1)
    .CARRYINSELREG(1),                // Number of pipeline stages for CARRYINSEL (0 or 1)
    .CREG(1),                         // Number of pipeline stages for C (0 or 1)
    .DREG(1),                         // Number of pipeline stages for D (0 or 1)
    .INMODEREG(0),                    // Number of pipeline stages for INMODE (0 or 1)
    .MREG(1),                         // Number of multiplier pipeline stages (0 or 1)
    .OPMODEREG(1),                    // Number of pipeline stages for OPMODE (0 or 1)
    .PREG(1)                          // Number of pipeline stages for P (0 or 1)
)
DSP48E1_inst (
    // Cascade: 30-bit (each) output: Cascade Ports
    .ACOUT(),                   // 30-bit output: A port cascade output
    .BCOUT(),                   // 18-bit output: B port cascade output
    .CARRYCASCOUT(),            // 1-bit output: Cascade carry output
    .MULTSIGNOUT(),             // 1-bit output: Multiplier sign cascade output
    .PCOUT(),                   // 48-bit output: Cascade output
    // Control: 1-bit (each) output: Control Inputs/Status Bits
    .OVERFLOW(),                // 1-bit output: Overflow in add/acc output
    .PATTERNBDETECT(dsp_patternbdetect), // 1-bit output: Pattern bar detect output
    .PATTERNDETECT(dsp_patterndetect),   // 1-bit output: Pattern detect output
    .UNDERFLOW(),               // 1-bit output: Underflow in add/acc output
    // Data: 4-bit (each) output: Data Ports
    .CARRYOUT(),    // 4-bit output: Carry output
    .P(dsp_p_out),              // 48-bit output: Primary data output
    // Cascade: 30-bit (each) input: Cascade Ports
    .ACIN(),                     // 30-bit input: A cascade data input
    .BCIN(),                     // 18-bit input: B cascade input
    .CARRYCASCIN(),              // 1-bit input: Cascade carry input
    .MULTSIGNIN(),               // 1-bit input: Multiplier sign input
    .PCIN(),                     // 48-bit input: P cascade input
    // Control: 4-bit (each) input: Control Inputs/Status Bits
    .ALUMODE(dsp_alumode),               // 4-bit input: ALU control input
    .CARRYINSEL(dsp_carryinsel),         // 3-bit input: Carry select input
    .CLK(CLK),                       // 1-bit input: Clock input
    .INMODE(dsp_inmode),                 // 5-bit input: INMODE control input
    .OPMODE(dsp_opmode),                 // 7-bit input: Operation mode input
    // Data: 30-bit (each) input: Data Ports
    .A(dsp_a_in),                           // 30-bit input: A data input
    .B(dsp_b_in),                           // 18-bit input: B data input
    .C(dsp_c_in),                           // 48-bit input: C data input
    .CARRYIN(dsp_carry_in),        // 1-bit input: Carry input signal
    .D(0),                           // 25-bit input: D data input
    // Reset/   Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
    .CEA1(alu_en & CE),                         // 1-bit input: Clock enable input for 1st stage AREG
    .CEA2(CE),                                  // 1-bit input: Clock enable input for 2nd stage AREG
    .CEAD(0),                         // 1-bit input: Clock enable input for ADREG
    .CEALUMODE((alu_en_1|call_en_1) & CE),                    // 1-bit input: Clock enable input for ALUMODE
    .CEB1(alu_en & CE),                         // 1-bit input: Clock enable input for 1st stage BREG
    .CEB2(CE),                                  // 1-bit input: Clock enable input for 2nd stage BREG
    .CEC(CE),                                   // 1-bit input: Clock enable input for CREG
    .CECARRYIN((alu_en_1|call_en_1) & CE),                    // 1-bit input: Clock enable input for CARRYINREG
    .CECTRL((alu_en_1|call_en_1) & CE),                       // 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
    .CED(0),                                   // 1-bit input: Clock enable input for DREG
    .CEINMODE(0),                           // 1-bit input: Clock enable input for INMODEREG
    .CEM(is_mul_op_1 & CE),                                // 1-bit input: Clock enable input for MREG
    .CEP(CE), //ce_alu_1                         // 1-bit input: Clock enable input for PREG
    // reset
    .RSTA(dsp_reset),                      // 1-bit input: Reset input for AREG
    .RSTALLCARRYIN(dsp_reset),             // 1-bit input: Reset input for CARRYINREG
    .RSTALUMODE(dsp_reset),                // 1-bit input: Reset input for ALUMODEREG
    .RSTB(dsp_reset),                      // 1-bit input: Reset input for BREG
    .RSTC(dsp_reset),                      // 1-bit input: Reset input for CREG
    .RSTCTRL(dsp_reset),                   // 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
    .RSTD(0),                      // 1-bit input: Reset input for DREG and ADREG
    .RSTINMODE(0),                 // 1-bit input: Reset input for INMODEREG
    .RSTM(dsp_reset),                      // 1-bit input: Reset input for MREG
    .RSTP(dsp_reset)                       // 1-bit input: Reset input for PREG
);
// End of DSP48E1_inst instantiation


assign ALU_OUT = (result_mux_3 == `RESULT_MUX_LOW)  ? dsp_p_out[DATA_WIDTH-1:0]
               : (result_mux_3 == `RESULT_MUX_HIGH) ? dsp_p_out[DATA_WIDTH*2-1:DATA_WIDTH]  
               : (result_mux_3 == `RESULT_MUX_MEM)  ? mem_data_3  
               :                                      bus_data_3;  

assign debug_dsp_p_out = dsp_p_out;

endmodule
