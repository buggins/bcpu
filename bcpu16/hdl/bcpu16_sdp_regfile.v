/**
    BCPU16 : 16-bit 4-core barrel MCU project.
    Author: Vadim Lopatin, 2021
    License: LGPL v2
    Language: System Verilog
    Compatibility: universal

    Resources: 24 LUTs as distributed RAM on Xilinx Series 7 FPGA

    Module bcpu_regfile implements 8 regs * 16 bits * 4 threads (in default configuration) 

    Dual asynchronous read ports, single synchronous write port
*/

module bcpu16_sdp_regfile
#(
    // 16, 17, 18
    parameter DATA_WIDTH = 16,     
    // 2^3 regs * 2^2 threads = 5 bits for 32 registers addressing
    parameter REG_ADDR_WIDTH = 5    
)
(
    //=========================================
    // Synchronous write port
    // clock: write operation is done synchronously using this clock
    input wire CLK,
    input wire CE,
    // when WR_EN == 1, write value WR_DATA to address WR_ADDR on raising edge of CLK 
    input wire WR_EN,
    input wire [REG_ADDR_WIDTH-1:0] WR_ADDR,
    input wire [DATA_WIDTH-1:0] WR_DATA,
    
    //=========================================
    // Asynchronous read port
    // always exposes value from address RD_ADDR to RD_DATA
    input wire [REG_ADDR_WIDTH-1:0] RD_ADDR,
    output wire [DATA_WIDTH-1:0] RD_DATA
);

localparam MEMSIZE = 1 << REG_ADDR_WIDTH;
reg [DATA_WIDTH-1:0] memory[MEMSIZE-1:0];

integer i = 0;
initial begin
    for (i = 0; i < MEMSIZE; i = i + 1) begin
        memory[i] = 0;
    end
end

// synchronous write
always @(posedge CLK)
    if (WR_EN & CE)
        memory[wr_addr_0] <= WR_DATA;

// asynchronous read
assign RD_DATA = memory[rd_addr_0];

endmodule
