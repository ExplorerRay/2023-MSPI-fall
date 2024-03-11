`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/21/2023 08:46:55 PM
// Design Name: 
// Module Name: dsa
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

module dsa #( parameter XLEN = 32, DSA_MEM_LEN = 1 ) (
    input                   clk_i,
    input                   rst_i,

    input                   en_i,
    input                   we_i,
    (* mark_debug = "true" *) input [2 : 0]           addr_i,
    input [XLEN-1 : 0]      data_i,
    output reg [XLEN-1 : 0] data_o,
    output reg              data_ready_o
);

integer idx;

(* mark_debug = "true" *) reg [XLEN-1 : 0] dsa_mem[0:4];
// 0 for weight, 1 for neuron, 2 for lock, 4 for result
//(* mark_debug = "true" *) reg  [XLEN-1 : 0] dsa_mem_nn[0: DSA_MEM_LEN-1];
//(* mark_debug = "true" *) reg  [XLEN-1 : 0] dsa_mem_wt[0: DSA_MEM_LEN-1];
//(* mark_debug = "true" *) reg  [DSA_MEM_LEN-1 : 0] cnt;

(* mark_debug = "true" *) wire result_valid;
(* mark_debug = "true" *) reg result_valid_reg;
(* mark_debug = "true" *) wire [XLEN-1 : 0] result;

//(* mark_debug = "true" *) wire wt_rdy, nn_rdy;
(* mark_debug = "true" *) reg wt_valid;
(* mark_debug = "true" *) reg nn_valid;
(* mark_debug = "true" *) reg c_valid;

(* mark_debug = "true" *) reg [31:0] data_fed_cycle; // after addr == 3'h4 to A valid

wire computing;
reg compt_reg;
(* mark_debug = "true" *) reg [31:0] compute_cycle; // after A,B,C valid UNTIL result_valid(from 0 to 1)
(* mark_debug = "true" *) reg [15:0] compute_cnt;

assign computing = wt_valid && nn_valid && c_valid;

always @(posedge clk_i)
begin
    compt_reg <= computing;
    if(rst_i) begin
        data_fed_cycle <= 32'b0;
        
        compute_cnt <= 16'b0;
        compute_cycle <= 32'b0;
    end
    else begin
        if(computing) compute_cycle <= compute_cycle + 1;
        
        if(compt_reg == 0 && computing == 1) compute_cnt <= compute_cnt + 1;
    end
end

always @(posedge clk_i)
begin
    if (rst_i)
    begin
        //cnt <= 0;
        wt_valid <= 0;
        nn_valid <= 0;
        result_valid_reg <= 0;
        c_valid <= 1; // NOT SURE
        for (idx = 0; idx <= 4; idx = idx + 1)
            dsa_mem[idx] <= 32'b0;
//            dsa_mem_nn[idx] <= 32'b0;
//            dsa_mem_wt[idx] <= 32'b0;
    end
    else begin
        result_valid_reg <= result_valid;
        if (we_i) begin
            if(addr_i == 3'h0) begin // weight
                wt_valid <= 1;
                dsa_mem[0] <= data_i;
                //dsa_mem_wt[cnt] <= data_i;
                //dsa_mem_wt[0] <= data_i;
            end
            else if(addr_i == 3'h1) begin // neuron
                nn_valid <= 1;
                dsa_mem[1] <= data_i;
                //dsa_mem_nn[cnt] <= data_i;
                //dsa_mem_nn[0] <= data_i;
            end
            else if(result_valid) begin
                nn_valid <= 0;
                wt_valid <= 0;
            end
        end
        else if(result_valid) begin
            nn_valid <= 0;
            wt_valid <= 0;
        end
        
        if(addr_i == 3'h4) dsa_mem[4] <= 32'b0;
        else if(result_valid == 0 && result_valid_reg == 1) dsa_mem[4] <= result;
        
        // lock and c
        if(result_valid == 0 && result_valid_reg == 1) begin
            c_valid <= 1;
            dsa_mem[2] <= 32'b1;
//            if(dsa_mem[0]==32'b0 || dsa_mem[1]==32'b0) dsa_mem[4] <= 32'b0;
//            else dsa_mem[4] <= result;
        end
        else if (addr_i == 3'h1) dsa_mem[2] <= 32'b0;
        
//        if(result_valid) begin 
//            c_valid <= 1;
//            dsa_mem[2] <= 32'b1;
//            dsa_mem[4] <= result;
//        end
//        else dsa_mem[2] <= 32'b0;
    end
end

always @(posedge clk_i)
begin
    if (en_i)
    begin
        data_o <= dsa_mem[addr_i];
        data_ready_o <= 1;   // CJ Tsai 0306_2020: Add ready signal for bus masters.
    end
    else
        data_ready_o <= 0;
end

floating_point_0 mtp_add_fp_IP (
    .aclk(clk_i),
    //,.aresetn(~rst_i)
    
    .s_axis_a_tvalid(wt_valid),
    .s_axis_a_tdata(dsa_mem[0]),
    
    .s_axis_b_tvalid(nn_valid),
    .s_axis_b_tdata(dsa_mem[1]),
    
    .s_axis_c_tvalid(c_valid),
    .s_axis_c_tdata(dsa_mem[4]),
    
    .m_axis_result_tvalid(result_valid),
    .m_axis_result_tdata(result)
);
endmodule

