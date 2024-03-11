`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/10/2023 03:36:26 PM
// Design Name: 
// Module Name: profiler
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module profiler #(
    parameter XLEN          = 32
)
(
    // System signals.
    input                 clk_i,
    input                 rst_i,
    
    //program counter from WriteBacK stage
    input   [XLEN-1:0]  wbk_pc_i,
    
    // checking cycle type
    input chk_stall_i,
    input chk_mem_i,
    
    // output counting
    output  [31:0]      total_cnt_o,
    output  [32*5-1:0]      prof_cnt_o,
    output  [32*5-1:0]      stall_cnt_o,
    output  [32*5-1:0]      mem_cnt_o
);

reg [31:0]  cnt_from_start; // total counter
(* mark_debug = "true" *) wire         chk_start;
reg [32*5-1:0]  prof_cnt; // profiler counter (5 in total)
wire         func_start[0:4]; //check function start
reg [32*5-1:0]  stall_cnt;
reg [32*5-1:0]  mem_cnt;
//reg [10-1:0]    count = 10'b0; //per 1024 clk add 1 counter

assign total_cnt_o = cnt_from_start;
assign prof_cnt_o = prof_cnt;
assign stall_cnt_o = stall_cnt;
assign mem_cnt_o = mem_cnt;

// initialize
//always @(*) begin
//    if (rst_i) begin
//        cnt_from_start <= 16'b0;
//        chk_start <= 1'b0;
//        prof_cnt[0] <= 16'b0;
//        prof_cnt[1] <= 16'b0;
//        prof_cnt[2] <= 16'b0;
//        prof_cnt[3] <= 16'b0;
//        prof_cnt[4] <= 16'b0;
//        func_start[0] <= 1'b0;
//        func_start[1] <= 1'b0;
//        func_start[2] <= 1'b0;
//        func_start[3] <= 1'b0;
//        func_start[4] <= 1'b0;
//        count <= 10'b0;
//    end
//end


/*
0x00001000          START

start       end     function
0x00001d28  1d7c    core_list_find
0x00002a14  2d0c    core_state_transition
0x00001d80  1da0    core_list_reverse
0x000019e8  1a28    crcu8
0x00002670  272c    matrix_mul_matrix_bitextract
*/
assign chk_start = (wbk_pc_i[15:0]>=16'h1000 && wbk_pc_i[15:0]<=16'h8000);
assign func_start[0] = (wbk_pc_i[15:0]>=16'h1d28 && wbk_pc_i[15:0]<=16'h1d7c);
assign func_start[1] = (wbk_pc_i[15:0]>=16'h2a14 && wbk_pc_i[15:0]<=16'h2d0c);
assign func_start[2] = (wbk_pc_i[15:0]>=16'h1d80 && wbk_pc_i[15:0]<=16'h1da0);
assign func_start[3] = (wbk_pc_i[15:0]>=16'h19e8 && wbk_pc_i[15:0]<=16'h1a28);
assign func_start[4] = (wbk_pc_i[15:0]>=16'h2670 && wbk_pc_i[15:0]<=16'h272c);

//always @(posedge clk_i) begin
//    if (rst_i) begin
//        func_start[0] <= 1'b0;
//        func_start[1] <= 1'b0;
//        func_start[2] <= 1'b0;
//        func_start[3] <= 1'b0;
//    end
//    else begin
//        casez(wbk_pc_i[15:0])
//            16'h1000: chk_start = 1'b1;
//            16'h1d28: func_start[0] = 1'b1; // core_list_find
//            16'h1d7c: func_start[0] = 1'b0;
//            16'h2a14: func_start[1] = 1'b1; //core_state_transition
//            16'h2d10: func_start[1] = 1'b0;
//            16'h1d80: func_start[2] = 1'b1;// core_list_reverse
//            16'h1da0: func_start[2] = 1'b0;
//            16'h19e8: func_start[3] = 1'b1;
//            16'h1a28: func_start[3] = 1'b0;
//            16'h2670: func_start[4] = 1'b1;
//            16'h272c: func_start[4] = 1'b0;
//        endcase
//    end
//end

always @(posedge clk_i) begin
    if (rst_i) begin
        prof_cnt <= 160'b0;
        cnt_from_start <= 32'b0;
    end
    else begin
        if (chk_start) cnt_from_start <= cnt_from_start + 1;
        if (func_start[0]) begin
            prof_cnt[31:0] <= prof_cnt[31:0] + 1;
            if (chk_stall_i) stall_cnt[31:0] <= stall_cnt[31:0] + 1;
            if (chk_mem_i) mem_cnt[31:0] <= mem_cnt[31:0] + 1;
        end
        if (func_start[1]) begin
            prof_cnt[63:32] <= prof_cnt[63:32] + 1;
            if (chk_stall_i) stall_cnt[63:32] <= stall_cnt[63:32] + 1;
            if (chk_mem_i) mem_cnt[63:32] <= mem_cnt[63:32] + 1;
        end
        if (func_start[2]) begin
            prof_cnt[95:64] <= prof_cnt[95:64] + 1;
            if (chk_stall_i) stall_cnt[95:64] <= stall_cnt[95:64] + 1;
            if (chk_mem_i) mem_cnt[95:64] <= mem_cnt[95:64] + 1;
        end
        if (func_start[3]) begin
            prof_cnt[127:96] <= prof_cnt[127:96] + 1;
            if (chk_stall_i) stall_cnt[127:96] <= stall_cnt[127:96] + 1;
            if (chk_mem_i) mem_cnt[127:96] <= mem_cnt[127:96] + 1;
        end
        if (func_start[4]) begin
            prof_cnt[159:128] <= prof_cnt[159:128] + 1;
            if (chk_stall_i) stall_cnt[159:128] <= stall_cnt[159:128] + 1;
            if (chk_mem_i) mem_cnt[159:128] <= mem_cnt[159:128] + 1;
        end
    end
end

endmodule
