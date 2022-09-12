`timescale 1ns / 1ps
/**
    BCPU16 : 16-bit barrel MCU project.
    Author: Vadim Lopatin, 2021
    License: LGPL v2
    Language: System Verilog
    Compatibility: universal
    Resources: no LUTs, 1 RAMB18 for address width 10, 2 RAMB36 for address width 12 on Xilinx Series 7 FPGA

    Module bcpu_dualport_bram contains implementation of dual port memory for program and data of bcpu16 core.
    
*/

module bcpu_dualport_bram
#(
    // data width
    parameter DATA_WIDTH = 32,
    // address width
    parameter ADDR_WIDTH = 12,
    // specify init file to fill ram with
    parameter INIT_FILE = "",
    // port A output register flag
    parameter A_REG = 1,
    // port B output register flag
    parameter B_REG = 1
)
(
    // clock
    input wire CLK,
    // reset, active 1
    input wire RESET,
    // clock enable
    input wire CE,

    //====================================
    // Port A    
    // 1 to start port A read or write operation
    input wire PORT_A_EN, 
    // enable port A write
    input wire PORT_A_WREN,
    // port A address 
    input wire [ADDR_WIDTH-1:0] PORT_A_ADDR, 
    // port A write data 
    input wire [DATA_WIDTH-1:0] PORT_A_WRDATA, 
    // port A read data 
    output wire [DATA_WIDTH-1:0] PORT_A_RDDATA, 
    //====================================
    // Port B    
    // 1 to start port B read or write operation
    input wire PORT_B_EN, 
    // enable port B write
    input wire PORT_B_WREN,
    // port B address 
    input wire [ADDR_WIDTH-1:0] PORT_B_ADDR, 
    // port B write data 
    input wire [DATA_WIDTH-1:0] PORT_B_WRDATA, 
    // port B read data 
    output wire [DATA_WIDTH-1:0] PORT_B_RDDATA 
);

reg port_a_rden1;
reg port_b_rden1;
always @(posedge CLK) begin
    if (RESET) begin
        port_a_rden1 <= 0;
        port_b_rden1 <= 0;
    end else if (CE) begin
        port_a_rden1 <= PORT_A_EN & ~PORT_A_WREN;
        port_b_rden1 <= PORT_B_EN & ~PORT_B_WREN;
    end
end

localparam MEMSIZE = 1 << ADDR_WIDTH;
reg [DATA_WIDTH-1:0] memory[MEMSIZE-1:0];

// The following code either initializes the memory values to a specified file or to all zeros to match hardware
generate
    if (INIT_FILE != "") begin: use_init_file
        initial
            $readmemh(INIT_FILE, memory, 0, MEMSIZE-1);
    end else begin: init_bram_to_zero
        integer ram_index;
        initial
            for (ram_index = 0; ram_index < MEMSIZE; ram_index = ram_index + 1)
                memory[ram_index] = {DATA_WIDTH{1'b0}};
    end
endgenerate



reg [DATA_WIDTH-1:0] port_a_rddata;
reg [DATA_WIDTH-1:0] port_b_rddata;

always @(posedge CLK)
    if (CE & PORT_A_EN) begin
        if (PORT_A_WREN)
            memory[PORT_A_ADDR] <= PORT_A_WRDATA;
        else
            port_a_rddata <= memory[PORT_A_ADDR];
    end 

always @(posedge CLK)
    if (CE & PORT_B_EN) begin
        if (PORT_B_WREN)
            memory[PORT_B_ADDR] <= PORT_B_WRDATA;
        else
            port_b_rddata <= memory[PORT_B_ADDR];
    end 


generate

    // A output
    if (A_REG == 1) begin
        // with output register (2-stage)
        reg [DATA_WIDTH-1:0] a_rddata_buf;
        assign PORT_A_RDDATA = a_rddata_buf; 
        always @(posedge CLK)
            if (RESET)
                a_rddata_buf <= 'b0;
            else if (CE & port_a_rden1)
                a_rddata_buf <= port_a_rddata;
    end else begin
        // without output register (1-stage)
        assign PORT_A_RDDATA = port_a_rddata; 
    end

    // B output
    if (B_REG == 1) begin
        // with output register (2-stage)
        reg [DATA_WIDTH-1:0] b_rddata_buf;
        assign PORT_B_RDDATA = b_rddata_buf; 
        always @(posedge CLK)
            if (RESET)
                b_rddata_buf <= 'b0;
            else if (CE & port_b_rden1)
                b_rddata_buf <= port_b_rddata;
    end else begin
        // without output register (1-stage)
        assign PORT_B_RDDATA = port_b_rddata; 
    end
endgenerate

endmodule
