#*****************************************************************************************
#  Create the aquial_bare workspace.
#*****************************************************************************************

# Adjust verison differences of the script. There is a change to the directory
# structure since Vivado 2021.1
#
set ver [version -short]
scan $ver %d.%d vmajor vminor
if { $vmajor > 2020 } {
    set gen_srcs gen
} else {
    set gen_srcs srcs
}

# Set the reference directory for source file relative paths
set origin_dir "."

# Set the project name
set proj_name "aquila_mpd"

variable script_file
set script_file "${proj_name}.tcl"

# Create project
create_project ${proj_name} ./${proj_name} -part xc7a100tcsg324-1

# Set project properties
set obj [current_project]
set_property -name "board_part" -value "digilentinc.com:arty-a7-100:part0:1.0" -objects $obj
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC XPM_MEMORY" -objects $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]

# Import local files from the original project
set files [list \
 [file normalize "$origin_dir/src/core_rtl/alu.v" ]\
 [file normalize "$origin_dir/src/core_rtl/aquila_config.vh" ]\
 [file normalize "$origin_dir/src/core_rtl/aquila_top.v" ]\
 [file normalize "$origin_dir/src/core_rtl/atomic_unit.v" ]\
 [file normalize "$origin_dir/src/core_rtl/bcu.v" ]\
 [file normalize "$origin_dir/src/core_rtl/bpu.v" ]\
 [file normalize "$origin_dir/src/core_rtl/clint.v" ]\
 [file normalize "$origin_dir/src/core_rtl/core_top.v" ]\
 [file normalize "$origin_dir/src/core_rtl/csr_file.v" ]\
 [file normalize "$origin_dir/src/core_rtl/decode.v" ]\
 [file normalize "$origin_dir/src/core_rtl/distri_ram.v" ]\
 [file normalize "$origin_dir/src/core_rtl/execute.v" ]\
 [file normalize "$origin_dir/src/core_rtl/fetch.v" ]\
 [file normalize "$origin_dir/src/core_rtl/forwarding_unit.v" ]\
 [file normalize "$origin_dir/src/core_rtl/memory.v" ]\
 [file normalize "$origin_dir/src/core_rtl/muldiv.v" ]\
 [file normalize "$origin_dir/src/core_rtl/pipeline_control.v" ]\
 [file normalize "$origin_dir/src/core_rtl/program_counter.v" ]\
 [file normalize "$origin_dir/src/core_rtl/reg_file.v" ]\
 [file normalize "$origin_dir/src/core_rtl/sram_dp.v" ]\
 [file normalize "$origin_dir/src/core_rtl/writeback.v" ]\
 [file normalize "$origin_dir/src/soc_rtl/uart.v" ]\
 [file normalize "$origin_dir/src/soc_rtl/soc_top.v" ]\
 [file normalize "$origin_dir/src/soc_rtl/soc_tb.v" ]\
 [file normalize "$origin_dir/src/soc_rtl/profiler.v"]\
 [file normalize "$origin_dir/src/mem/uartboot.mem" ]\
]
set imported_files [import_files -fileset sources_1 $files]

# Define the target board to "ARTY" for synthesis
set_property verilog_define ARTY=true [get_filesets sources_1]

# Set 'sources_1' fileset file properties for local files
set obj [get_filesets sources_1]
set_property -name "top" -value "soc_top" -objects $obj
set file "mem/uartboot.mem"
set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
set_property -name "file_type" -value "Memory File" -objects $file_obj

# Import and set 'constrs_1' fileset file properties for local files
set files [list \
 [file normalize "$origin_dir/src/xdc/arty.xdc"]\
]
set imported_files [import_files -fileset constrs_1 $files]
set file "xdc/arty.xdc"
set file_objs [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property -name "file_type" -value "XDC" -objects $file_objs

# Set 'sim_1' fileset object

# Define the target board to "ARTY" for simulation
set_property verilog_define ARTY=true [get_filesets sim_1]

set obj [get_filesets sim_1]
set_property -name "top" -value "soc_tb" -objects $obj
set_property -name "top_lib" -value "xil_defaultlib" -objects $obj

# Adding a Clock Wizard IP
# For some platforms, you may have to set CONFIG.PRIM_SOURCE {No_buffer}
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {41.66667} \
    CONFIG.CLKOUT2_USED {false} \
    CONFIG.USE_RESET {false} \
    CONFIG.USE_LOCKED {false}] [get_ips clk_wiz_0]
generate_target all [get_files ${proj_name}/${proj_name}.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0.xci]

puts "INFO: Project created:${proj_name}"
