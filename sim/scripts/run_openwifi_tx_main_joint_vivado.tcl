# Windows-friendly openwifi TX main-link joint simulation.
# Arguments:
#   0: openwifi-hw-git root directory
#   1: TX memory file with two generated PHY header words followed by payload words
#   2: result directory
#   3: simulation time in us, default 120
#   4: case name, default ht_mcs7_gi1_aggr0_byte100
#   5: total 64-bit words in TX memory file, default 15
#   6: PSDU bytes, default 100
#   7: tx_intf slv_reg17 value, default 32'h0007C064
#   8: timeout cycles at 100 MHz, default 120000

set hw_root [file normalize [lindex $argv 0]]
set mem_file [file normalize [lindex $argv 1]]
set result_dir [file normalize [lindex $argv 2]]
set sim_time_us [lindex $argv 3]
set case_name [lindex $argv 4]
set mem_total_words [lindex $argv 5]
set psdu_bytes [lindex $argv 6]
set slv_reg17_value [lindex $argv 7]
set timeout_cycles [lindex $argv 8]

if {$sim_time_us eq ""} {
  set sim_time_us "120"
}
if {$case_name eq ""} {
  set case_name "ht_mcs7_gi1_aggr0_byte100"
}
if {$mem_total_words eq ""} {
  set mem_total_words "15"
}
if {$psdu_bytes eq ""} {
  set psdu_bytes "100"
}
if {$slv_reg17_value eq ""} {
  set slv_reg17_value "32'h0007C064"
}
if {$timeout_cycles eq ""} {
  set timeout_cycles "120000"
}

set script_dir [file dirname [file normalize [info script]]]
set tx_intf_src [file normalize [file join $hw_root ip tx_intf src]]
set openofdm_tx_src [file normalize [file join $hw_root ip openofdm_tx src]]
set tb_file [file normalize [file join $script_dir .. compat openwifi_tx_main_joint_tb.v]]
set work_base [file normalize [file join $script_dir .. work]]
set project_name "openwifi_tx_main_joint"
set project_dir [file normalize [file join $work_base $project_name]]

file mkdir $result_dir
file mkdir $work_base
file delete -force $project_dir

puts "TX_MAIN_JOINT_SIM_START hw_root=$hw_root"
puts "TX_MAIN_JOINT_SIM_MEM $mem_file"
puts "TX_MAIN_JOINT_SIM_RESULT_DIR $result_dir"

if {![file exists $hw_root]} {
  error "Missing hw_root: $hw_root"
}
if {![file exists $mem_file]} {
  error "Missing TX mem file: $mem_file"
}
if {![file exists $tb_file]} {
  error "Missing TX joint testbench: $tb_file"
}

create_project $project_name $project_dir -part xc7z020clg484-1 -force
set_property target_language Verilog [current_project]
set_property target_simulator XSim [current_project]
set_property simulator_language Mixed [current_project]
set_property xpm_libraries {XPM_CDC XPM_MEMORY} [current_project]
set_property xsim.array_display_limit 1024 [current_project]
set_property xsim.radix hex [current_project]
set_property xsim.time_unit ns [current_project]
set_property xsim.trace_limit 65536 [current_project]

set tx_intf_files [list \
  [file join $tx_intf_src dac_intf.v] \
  [file join $tx_intf_src div_int.v] \
  [file join $tx_intf_src ht_sig_crc_calc.v] \
  [file join $tx_intf_src tx_bit_intf.v] \
  [file join $tx_intf_src tx_interrupt_selection.v] \
  [file join $tx_intf_src tx_intf_s_axi.v] \
  [file join $tx_intf_src tx_intf_s_axis.v] \
  [file join $tx_intf_src tx_iq_intf.v] \
  [file join $tx_intf_src edge_to_flip.v] \
  [file join $tx_intf_src csi_fuzzer.v] \
  [file join $tx_intf_src tx_status_fifo.v] \
  [file join $tx_intf_src tx_intf.v] \
]

set openofdm_tx_files [list \
  [file join $openofdm_tx_src axi_fifo_bram.v] \
  [file join $openofdm_tx_src bimpy.v] \
  [file join $openofdm_tx_src bitreverse.v] \
  [file join $openofdm_tx_src butterfly.v] \
  [file join $openofdm_tx_src convround.v] \
  [file join $openofdm_tx_src hwbfly.v] \
  [file join $openofdm_tx_src ifftmain.v] \
  [file join $openofdm_tx_src ifftstage.v] \
  [file join $openofdm_tx_src longbimpy.v] \
  [file join $openofdm_tx_src qtrstage.v] \
  [file join $openofdm_tx_src ram_simo.v] \
  [file join $openofdm_tx_src punc_interlv_lut.v] \
  [file join $openofdm_tx_src laststage.v] \
  [file join $openofdm_tx_src dpram.v] \
  [file join $openofdm_tx_src convenc.v] \
  [file join $openofdm_tx_src l_stf_rom.v] \
  [file join $openofdm_tx_src l_ltf_rom.v] \
  [file join $openofdm_tx_src ht_stf_rom.v] \
  [file join $openofdm_tx_src ht_ltf_rom.v] \
  [file join $openofdm_tx_src crc32_tx.v] \
  [file join $openofdm_tx_src dot11_tx.v] \
  [file join $openofdm_tx_src modulation.v] \
  [file join $openofdm_tx_src openofdm_tx_s_axi.v] \
  [file join $openofdm_tx_src openofdm_tx.v] \
  [file join $openofdm_tx_src icmem_64.mem] \
  [file join $openofdm_tx_src icmem_8.mem] \
  [file join $openofdm_tx_src icmem_16.mem] \
  [file join $openofdm_tx_src icmem_32.mem] \
]

foreach f [concat $tx_intf_files $openofdm_tx_files] {
  if {![file exists $f]} {
    error "Missing TX source: $f"
  }
  add_files -norecurse -fileset sources_1 $f
}

add_files -norecurse -fileset sim_1 $tb_file

set include_dirs [list $tx_intf_src $openofdm_tx_src]
set_property include_dirs $include_dirs [get_filesets sources_1]
set_property include_dirs $include_dirs [get_filesets sim_1]

set mem_file_for_verilog [string map {\\ /} $mem_file]
set tx_mem_define "TX_MEM_FILE=\"$mem_file_for_verilog\""
set case_name_define "TX_CASE_NAME=\"$case_name\""
set mem_words_define "TX_MEM_TOTAL_WORDS=$mem_total_words"
set psdu_bytes_define "TX_PSDU_BYTES=$psdu_bytes"
set slv_reg17_define "TX_SLV_REG17_VALUE=$slv_reg17_value"
set timeout_define "TX_TIMEOUT_CYCLES=$timeout_cycles"
set_property verilog_define [list $tx_mem_define $case_name_define $mem_words_define $psdu_bytes_define $slv_reg17_define $timeout_define] [get_filesets sim_1]
set_property top openwifi_tx_main_joint_tb [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set wdb_path [file normalize [file join $result_dir openwifi_tx_main_joint.wdb]]
set_property xsim.simulate.wdb $wdb_path [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
restart
log_wave -r /*
puts "TX_MAIN_JOINT_SIM_RUN ${sim_time_us}us"
run ${sim_time_us}us

set xsim_dir [file normalize [file join $project_dir ${project_name}.sim sim_1 behav xsim]]
foreach f [glob -nocomplain -directory $xsim_dir *.txt] {
  file copy -force $f $result_dir
}
foreach f [glob -nocomplain -directory $xsim_dir *.csv] {
  file copy -force $f $result_dir
}

puts "TX_MAIN_JOINT_SIM_XSIM_DIR $xsim_dir"
puts "TX_MAIN_JOINT_SIM_WDB $wdb_path"
puts "TX_MAIN_JOINT_SIM_DONE"
