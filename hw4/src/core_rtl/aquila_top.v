`timescale 1 ns / 1 ps
// =============================================================================
//  Program : aquila_top.v
//  Author  : Chun-Jen Tsai
//  Date    : Oct/08/2019
// -----------------------------------------------------------------------------
//  Description:
//  This is the top-level Aquila IP wrapper for an AXI-based processor SoC.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  This module is based on the soc_top.v module written by Jin-you Wu
//  on Feb/28/2019. The original module was a stand-alone top-level module
//  for an SoC. This rework makes it a module embedded inside an AXI IP.
//
//  Jan/12/2020, by Chun-Jen Tsai:
//    Added a on-chip Tightly-Coupled Memory (TCM) to the aquila SoC.
//
//  Mar/05/2020, by Chih-Yu Hsiang:
//    Support for A standard extension.
//
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Chiao Tung Uniersity
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================
`include "aquila_config.vh"

module aquila_top #
(
    parameter integer HART_ID  = 0,
    parameter integer XLEN     = 32,  // Width of RISCV registers.
    parameter integer CLSIZE   = `CLP // Size of a cache block in bits.
)
(
    input                 clk_i,
    input                 rst_i,   // level-sensitive reset signal.

    // Initial program counter address for the Aquila core
    input  [XLEN-1 : 0]   base_addr_i,

    // Aquila external instruction memory interface signals
    output                M_IMEM_strobe_o,
    output [XLEN-1 : 0]   M_IMEM_addr_o,
    input                 M_IMEM_done_i,
    input  [CLSIZE-1 : 0] M_IMEM_data_i,

    // Aquila external data memory interface signals
    output                M_DMEM_strobe_o,
    output [XLEN-1 : 0]   M_DMEM_addr_o,
    output                M_DMEM_rw_o,
    output [CLSIZE-1 : 0] M_DMEM_data_o,
    input                 M_DMEM_done_i,
    input  [CLSIZE-1 : 0] M_DMEM_data_i,

    // Aquila M_DEVICE master port interface signals
    output                M_DEVICE_strobe_o,
    output [XLEN-1 : 0]   M_DEVICE_addr_o,
    output                M_DEVICE_rw_o,
    output [XLEN/8-1 : 0] M_DEVICE_byte_enable_o,
    output [XLEN-1 : 0]   M_DEVICE_data_o,
    input                 M_DEVICE_data_ready_i,
    input  [XLEN-1 : 0]   M_DEVICE_data_i
);

// ------------- Signals for cpu, cache and master ip -------------------------
// CPU core
wire                      code_sel;
wire [1 : 0]              data_sel;

// Cache flush signals
wire                      p_cache_flush;
wire                      dcache_flushing;

// Processor to instruction memory signals.
wire                      p_i_strobe;
wire                      p_i_ready;
wire [XLEN-1 : 0]         p_i_addr;
wire [XLEN-1 : 0]         p_i_code;

wire [XLEN-1 : 0]         code_from_tcm;
wire [XLEN-1 : 0]         code_from_cache;
wire                      tcm_i_ready;
wire                      cache_i_ready;

// Processor to data memory signals.
wire                      p_d_strobe;
wire                      p_d_ready;
wire [XLEN-1 : 0]         p_d_addr;
wire                      p_d_rw;
wire [XLEN/8-1 : 0]       p_d_byte_enable;
wire [XLEN-1 : 0]         p_d_mem2core;
wire [XLEN-1 : 0]         p_d_core2mem;

wire                      p_d_is_amo;    // Is it an atomic data access?
wire [4 : 0]              p_d_amo_type;  // Type of the atomic data access.

wire [XLEN-1 : 0]         data_from_tcm;
wire [XLEN-1 : 0]         data_from_cache;
wire                      tcm_d_ready;
wire                      cache_d_ready;

// I/D Caches to DDRx memory signals.
wire                      m_i_strobe, m_i_ready;
wire                      m_d_strobe, m_d_rw, m_d_ready;
wire [XLEN-1 : 0]         m_i_addr, m_d_addr;
wire [CLSIZE-1 : 0]       m_i_dram, m_d_cache2dram, m_d_dram2cache;

`ifdef ENABLE_ATOMIC_UNIT
wire                      m_d_is_amo;   // Atomic op flag to D-memory.
wire [4 : 0]              m_d_amo_type; // Atomic type to D-memory.

// Connections from the RISCV Core to the Atomic Unit, then to D-memory.
wire                      atomic_unit_strobe;
wire [XLEN-1 : 0]         atomic_unit_addr;
wire                      atomic_unit_rw;
wire [CLSIZE-1 : 0]       atomic_unit_dataout;
wire                      atomic_unit_done;
wire [CLSIZE-1 : 0]       atomic_unit_datain;
`endif

// Interrupt signals.
(* mark_debug = "true" *) wire tmr_irq;
wire sft_irq;

// The processor pipeline cannot be interrupted when
// external memory or device accesses is in progress.
wire is_ext_addr = (data_sel != 2'b0);

// System device data bus.
wire [XLEN-1 : 0]         data_from_sysdev;
wire                      sysdev_d_ready;

// ------ System Memory Map: DDRx DRAM, I/O Devices, or System Devices ---------
//       [0] 0x0000_0000 - 0x0FFF_FFFF : Tightly-Coupled Memory (TCM)
//       [1] 0x8000_0000 - 0xBFFF_FFFF : DDRx DRAM memory (cached)
//       [2] 0xC000_0000 - 0xCFFF_FFFF : device memory (uncached)
//       [3] 0xF000_0000 - 0xFFFF_FFFF : System devices (uncached)
//
wire [3 : 0] code_segment, data_segment;

assign code_segment = p_i_addr[XLEN-1:XLEN-4];
assign data_segment = p_d_addr[XLEN-1:XLEN-4];

assign code_sel = (code_segment == 4'h0)? 0 : 1;
assign data_sel = (data_segment == 4'h0)? 0 :
                  (data_segment == 4'hC)? 2 :
                  (data_segment == 4'hF)? 3 : 1;

assign p_i_code = (code_sel == 0)? code_from_tcm : code_from_cache;
assign p_i_ready = (code_sel == 0)? tcm_i_ready : cache_i_ready;

reg  [1:0] data_sel_r;
always @(posedge clk_i) begin
	data_sel_r <= data_sel;
end

// Delay the memory response by one clock cycle so that
//   the processor core will not miss the ready strobe.
assign p_d_mem2core = (data_sel_r == 0)? data_from_tcm :
                      (data_sel_r == 1)? data_from_cache :
                      (data_sel_r == 2)? M_DEVICE_data_i : data_from_sysdev;
assign p_d_ready = (data_sel_r == 0)? tcm_d_ready :
                   (data_sel_r == 1)? cache_d_ready :
                   (data_sel_r == 2)? M_DEVICE_data_ready_i : sysdev_d_ready;

// --- Master IP interface driving signals for I/D caches and I/O devices ---
assign M_IMEM_strobe_o = m_i_strobe;
assign M_IMEM_addr_o   = m_i_addr;
assign m_i_ready       = M_IMEM_done_i;
assign m_i_dram        = M_IMEM_data_i;

// From the Atomic Unit to the external memory controller
`ifdef ENABLE_ATOMIC_UNIT
assign M_DMEM_strobe_o = atomic_unit_strobe;
assign M_DMEM_addr_o   = atomic_unit_addr;
assign M_DMEM_rw_o     = atomic_unit_rw;
assign M_DMEM_data_o   = atomic_unit_dataout;

// From the external memory controller to the atomic unit
assign m_d_ready       = atomic_unit_done;
assign m_d_dram2cache  = atomic_unit_datain;

`else

assign M_DMEM_strobe_o = m_d_strobe;
assign M_DMEM_addr_o   = m_d_addr;
assign M_DMEM_rw_o     = m_d_rw;
assign M_DMEM_data_o   = m_d_cache2dram;

// From the external memory controller to the atomic unit
assign m_d_ready       = M_DMEM_done_i;
assign m_d_dram2cache  = M_DMEM_data_i;
`endif

assign M_DEVICE_strobe_o      = p_d_strobe && (data_sel == 2);
assign M_DEVICE_addr_o        = (data_sel == 2)? p_d_addr : 32'h0;
assign M_DEVICE_rw_o          = p_d_rw && (data_sel == 2);
assign M_DEVICE_byte_enable_o = p_d_byte_enable;
assign M_DEVICE_data_o        = (data_sel == 2)? p_d_core2mem : 32'h0;


// For checking FreeRTOS
(* mark_debug = "true" *) wire [XLEN-1 : 0] pc_ILA;
(* mark_debug = "true" *) reg [31 : 0] ctx_swch_cnt;
(* mark_debug = "true" *) reg [31 : 0] ctx_swch_cycles;
(* mark_debug = "true" *) reg [31 : 0] enter_crit_cnt;
(* mark_debug = "true" *) reg [31 : 0] enter_crit_cycles;
(* mark_debug = "true" *) reg [31 : 0] leave_crit_cnt;
(* mark_debug = "true" *) reg [31 : 0] leave_crit_cycles;
(* mark_debug = "true" *) reg [31 : 0] take_mtx_cnt;
(* mark_debug = "true" *) reg [31 : 0] take_mtx_cycles;
(* mark_debug = "true" *) reg [31 : 0] give_mtx_cnt;
(* mark_debug = "true" *) reg [31 : 0] give_mtx_cycles;


(* mark_debug = "true" *) wire chk_task1;
(* mark_debug = "true" *) wire chk_task2;
(* mark_debug = "true" *) reg task1_end;
(* mark_debug = "true" *) reg task2_end;
(* mark_debug = "true" *) wire chk_idle;
(* mark_debug = "true" *) reg chk_mtx_take;
(* mark_debug = "true" *) reg chk_mtx_give;
(* mark_debug = "true" *) wire chk_enter_crit;
(* mark_debug = "true" *) wire chk_leave_crit;

(* mark_debug = "true" *) reg tmr_irq_reg; //for posedge check
(* mark_debug = "true" *) wire tmr_irq_start; //for posedge check
(* mark_debug = "true" *) reg ctx_swch_running;


assign chk_task1 = (pc_ILA>=32'h800010e8 && pc_ILA<=32'h8000134c);
assign chk_task2 = ((pc_ILA>=32'h80001000 && pc_ILA<=32'h800010e4) || (pc_ILA>=32'h80002228 && pc_ILA<=32'h80002254));
assign chk_idle = (pc_ILA>=32'h80003e8c && pc_ILA<=32'h80003f60);
//assign chk_mtx_take = (pc_ILA>=32'h80003354 && pc_ILA<=32'h80003570); // ret 80003484
//assign chk_mtx_give = (pc_ILA>=32'h80002cb4 && pc_ILA<=32'h80002ea0); // ret 80002e68
assign chk_enter_crit = (pc_ILA>=32'h80004dc8 && pc_ILA<=32'h80004df0);
assign chk_leave_crit = (pc_ILA>=32'h80004df4 && pc_ILA<=32'h80004e30);

assign tmr_irq_start = (pc_ILA==32'h80007400 && !(task1_end && task2_end));
//assign tmr_irq_start = (tmr_irq_reg==1'b0 && tmr_irq==1'b1 && !(task1_end && task2_end));
//assign ctx_swch_running = (tmr_irq_start==1'b1 && (chk_task1 || chk_task2));

always @(posedge clk_i) begin
    if (rst_i) begin
        task1_end <= 1'b0;
        task2_end <= 1'b0;
        chk_mtx_take <= 1'b0;
        take_mtx_cnt <= 32'b0;
        give_mtx_cnt <= 32'b0;
        chk_mtx_give <= 1'b0;
        tmr_irq_reg <= 1'b0;
        ctx_swch_running <= 1'b0;
    end
    else begin
        if(pc_ILA==32'h80001314) task1_end <= 1;
        else task1_end <= task1_end;
        if(pc_ILA==32'h800010e4) task2_end <= 1;
        else task2_end <= task2_end;
        
        if(pc_ILA==32'h80003354) begin
            take_mtx_cnt <= take_mtx_cnt + 1;
            chk_mtx_take <= 1; // No handling timer interrupt
        end
        else if(pc_ILA==32'h80003484) chk_mtx_take <= 0;
        else chk_mtx_take <= chk_mtx_take;
        
        if(pc_ILA==32'h80002cb4) begin
            give_mtx_cnt <= give_mtx_cnt + 1;
            chk_mtx_give <= 1;
        end
        else if(pc_ILA==32'h80002e68) chk_mtx_give <= 0;
        else chk_mtx_give <= chk_mtx_give;
    
        tmr_irq_reg <= tmr_irq;
        if(tmr_irq_start) ctx_swch_running <= 1;
        else if(chk_task1 || chk_task2) ctx_swch_running <= 0;
        else ctx_swch_running <= ctx_swch_running;
    end
end

always @(posedge clk_i) begin
    if (rst_i) begin
        ctx_swch_cnt <= 32'b0;
        ctx_swch_cycles <= 32'b0;
        enter_crit_cnt <= 32'b0;
        enter_crit_cycles <= 32'b0;
        leave_crit_cnt <= 32'b0;
        leave_crit_cycles <= 32'b0;
        take_mtx_cycles <= 32'b0;
        give_mtx_cycles <= 32'b0;
    end
    else begin
        if (tmr_irq_reg==0 && tmr_irq==1 && !(task1_end && task2_end)) begin
            ctx_swch_cnt <= ctx_swch_cnt + 1;
        end
        
        if (chk_mtx_take) take_mtx_cycles <= take_mtx_cycles + 1;
        
        if (chk_mtx_give) give_mtx_cycles <= give_mtx_cycles + 1;
        
        if (chk_enter_crit) enter_crit_cycles <= enter_crit_cycles + 1;
        if (pc_ILA==32'h80004dc8) enter_crit_cnt <= enter_crit_cnt + 1;
        
        if (chk_leave_crit) leave_crit_cycles <= leave_crit_cycles + 1;
        if (pc_ILA==32'h80004df4) leave_crit_cnt <= leave_crit_cnt + 1;
        
        if (ctx_swch_running) ctx_swch_cycles <= ctx_swch_cycles + 1;
    end
end

// ----------------------------------------------------------------------------
//  Aquila processor core
//
core_top #(.HART_ID(HART_ID), .XLEN(XLEN))
RISCV_CORE0(
    // System signals
    .clk_i(clk_i),
    .rst_i(rst_i),          // from slave register
    .stall_i(1'b0),         // disable user stall signal

    // Program counter address at reset for the Aquila core
    .init_pc_addr_i(base_addr_i),

    // Instruction port
    .code_i(p_i_code),
    .code_ready_i(p_i_ready),
    .code_addr_o(p_i_addr),
    .code_req_o(p_i_strobe),

    // Data port
    .data_i(p_d_mem2core),
    .data_ready_i(p_d_ready),
    .data_o(p_d_core2mem),
    .data_addr_o(p_d_addr),
    .data_rw_o(p_d_rw),
    .data_byte_enable_o(p_d_byte_enable),
    .data_req_o(p_d_strobe),
    .data_is_amo_o(p_d_is_amo),
    .data_amo_type_o(p_d_amo_type),
    .data_addr_ext_i(is_ext_addr),

    // Cache flush signal
    .cache_flush_o(p_cache_flush),

    // Interrupt signals
    .ext_irq_i(1'b0),     // no external interrupt (yet)
    .tmr_irq_i(tmr_irq),
    .sft_irq_i(sft_irq),
    
    .pc_ILA_o(pc_ILA)
);

// ----------------------------------------------------------------------------
//  Instiantiation of the dual-port tightly-coupled scratchpad memory module.
//  0x00000000 ~ 0x0FFFFFFF
localparam TCM_ADDR_WIDTH = $clog2(`TCM_SIZE_IN_WORDS);

sram_dp #(.DATA_WIDTH(XLEN), .N_ENTRIES(`TCM_SIZE_IN_WORDS))
TCM(
    // Instruction memory ports
    .clk1_i(clk_i),
    .en1_i(p_i_strobe && (code_sel == 0)),
    .we1_i(1'b0),
    .be1_i(4'b1111),
    .addr1_i(p_i_addr[TCM_ADDR_WIDTH+1 : 2]),
    .data1_i({XLEN{1'b0}}),
    .data1_o(code_from_tcm),
    .ready1_o(tcm_i_ready),

    // Data memory ports
    .clk2_i(clk_i),
    .en2_i(p_d_strobe && (data_sel == 0)),
    .we2_i(p_d_rw && (data_sel == 0)),
    .be2_i(p_d_byte_enable),
    .addr2_i(p_d_addr[TCM_ADDR_WIDTH+1 : 2]),
    .data2_i(p_d_core2mem),  // data from processor write bus
    .data2_o(data_from_tcm),
    .ready2_o(tcm_d_ready)
);

// ----------------------------------------------------------------------------
//  Shared output signals for system devices.
wire [3 : 0]      sysdev_sel;
wire [XLEN-1 : 0] clint_dout;
wire              clint_d_ready;

assign sysdev_sel = p_d_addr[19 : 16];
assign data_from_sysdev = (|sysdev_sel)? {XLEN{1'b0}} : clint_dout;

// ----------------------------------------------------------------------------
//  We must fake the initial stack responses (at 0xFFFF_0000 ~ 0xFFFF_FFF0).
//  Any stack operations are ignored until sp is properly initialized.
//
assign sysdev_d_ready = (sysdev_sel == 4'h0)? clint_d_ready // 0xF000_0000 ~
                        : 1;                                // 0xF001_0000 ~

// ----------------------------------------------------------------------------
//  Instiantiation of the Core Local Interrupt controller (CLINT) module.
//
clint CLINT(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .en_i(sysdev_sel == 4'h0 && (data_sel == 3)),
    .we_i((data_sel == 3) && p_d_rw),
    .addr_i(p_d_addr[4 : 2]),
    .data_i(p_d_core2mem),
    .data_o(clint_dout),
    .data_ready_o(clint_d_ready),

    .tmr_irq_o(tmr_irq),
    .sft_irq_o(sft_irq)
);

// ----------------------------------------------------------------------------
//  The Atomic Unit (Overseer of RISCV atomic instructions).
//
// processor to atomic unit
`ifdef ENABLE_ATOMIC_UNIT
atomic_unit ATOM_U(
    .clk_i(clk_i),
    .rst_i(rst_i),

    .core_id_i(1'b1), // number of RISCV cores (# of core_top modules)
    .core_strobe_i(m_d_strobe),
    .core_addr_i(m_d_addr),
    .core_rw_i(m_d_rw),
    .core_data_i(m_d_cache2dram),
    .core_done_o(atomic_unit_done),
    .core_data_o(atomic_unit_datain),

    .core_is_amo_i(m_d_is_amo),
    .core_amo_type_i(m_d_amo_type),

    .M_DMEM_strobe_o(atomic_unit_strobe),
    .M_DMEM_addr_o(atomic_unit_addr),
    .M_DMEM_rw_o(atomic_unit_rw),
    .M_DMEM_data_o(atomic_unit_dataout),
    .M_DMEM_done_i(M_DMEM_done_i),
    .M_DMEM_data_i(M_DMEM_data_i)
);
`endif

`ifdef ENABLE_CACHE
// ----------------------------------------------------------------------------
//  Instiantiation of the I/D-cache modules.
//

// Instruction read from I-cache port.
icache #(.XLEN(XLEN), .CACHE_SIZE(`ICACHE_SIZE), .CLSIZE(CLSIZE))
I_Cache(
    .clk_i(clk_i),
    .rst_i(rst_i),

    .p_addr_i(p_i_addr),
    .p_strobe_i(p_i_strobe && (code_sel == 1)),
    .p_flush_i(p_cache_flush),
    .p_data_o(code_from_cache),
    .p_ready_o(cache_i_ready),

    .m_addr_o(m_i_addr),
    .m_data_i(m_i_dram),
    .m_strobe_o(m_i_strobe),
    .m_ready_i(m_i_ready),

    .d_flushing_i(dcache_flushing)
);

// Data read/write through D-cache port.
dcache #(.XLEN(XLEN), .CACHE_SIZE(`DCACHE_SIZE), .CLSIZE(CLSIZE))
D_Cache(
    .clk_i(clk_i),
    .rst_i(rst_i),

    .p_strobe_i(p_d_strobe && (data_sel == 1)),
    .p_rw_i(p_d_rw && (data_sel == 1)),
    .p_byte_enable_i(p_d_byte_enable),
    .p_addr_i(p_d_addr),
    .p_data_o(data_from_cache),
    .p_data_i(p_d_core2mem),
    .p_ready_o(cache_d_ready),
    .p_flush_i(p_cache_flush),
    .busy_flushing_o(dcache_flushing),

    .p_is_amo_i(p_d_is_amo),
    .p_amo_type_i(p_d_amo_type),
    .m_is_amo_o(m_d_is_amo),
    .m_amo_type_o(m_d_amo_type),

    .m_addr_o(m_d_addr),
    .m_data_i(m_d_dram2cache),
    .m_data_o(m_d_cache2dram),
    .m_strobe_o(m_d_strobe),
    .m_rw_o(m_d_rw),
    .m_ready_i(m_d_ready)
);
`endif

endmodule
