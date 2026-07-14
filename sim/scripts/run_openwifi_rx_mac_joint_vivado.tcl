# Windows-friendly openwifi RX + low-MAC joint simulation wrapper.
# Arguments:
#   0: openofdm_rx directory inside openwifi-hw-git/ip
#   1: IQ sample file
#   2: result directory
#   3: simulation time in us
#   4: board name, default zed_fmcs2
#   5: clock MHz, default 100
#   6: SAMPLE_FILE string compiled into the testbench, default is argument 1
#   7: log waves, default 1

set work_dir [file normalize [lindex $argv 0]]
set iq_file [file normalize [lindex $argv 1]]
set result_dir [file normalize [lindex $argv 2]]
set sim_time_us [lindex $argv 3]
set board_name [lindex $argv 4]
set clk_mhz [lindex $argv 5]
set sample_file_arg [lindex $argv 6]
set log_waves [lindex $argv 7]

if {$board_name eq ""} {
  set board_name "zed_fmcs2"
}
if {$clk_mhz eq ""} {
  set clk_mhz "100"
}
if {$sim_time_us eq ""} {
  set sim_time_us "120"
}
if {$log_waves eq ""} {
  set log_waves "1"
}

set script_dir [file dirname [file normalize [info script]]]
set compat_tcl [file normalize [file join $script_dir .. .. vivado_board_sim scripts vivado_unix_compat.tcl]]
source $compat_tcl

proc rx_mac_count_lines {path} {
  set fd [open $path r]
  set n 0
  while {[gets $fd line] >= 0} {
    incr n
  }
  close $fd
  return $n
}

proc rx_mac_copy_text_results {xsim_dir result_dir} {
  file mkdir $result_dir
  foreach f [glob -nocomplain -directory $xsim_dir *.txt] {
    file copy -force $f $result_dir
  }
  foreach f [glob -nocomplain -directory $xsim_dir *.csv] {
    file copy -force $f $result_dir
  }
}

file mkdir $result_dir
if {$sample_file_arg eq ""} {
  set sample_file_arg $iq_file
}
set iq_file_for_verilog [string map {\\ /} $sample_file_arg]

puts "RX_MAC_JOINT_SIM_START work_dir=$work_dir"
puts "RX_MAC_JOINT_SIM_IQ $iq_file_for_verilog"
puts "RX_MAC_JOINT_SIM_RESULT_DIR $result_dir"

cd $work_dir

set argv [list $board_name $clk_mhz $iq_file_for_verilog]
source ./openofdm_rx.tcl

set deinter_lut_mif_src [file normalize [file join $work_dir verilog deinter_lut.mif]]
set deinter_lut_mif_dst [file normalize [file join $work_dir ip_repo deinter_lut deinter_lut.mif]]
if {[file exists $deinter_lut_mif_src]} {
  file mkdir [file dirname $deinter_lut_mif_dst]
  file copy -force $deinter_lut_mif_src $deinter_lut_mif_dst
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set simset [get_filesets sim_1]
set hw_root [file normalize [file join $work_dir .. ..]]
set ip_root [file normalize [file join $hw_root ip]]
set xpu_src [file normalize [file join $ip_root xpu src]]
set rx_intf_src [file normalize [file join $ip_root rx_intf src]]

set rot_lut_ip_files [get_files -quiet -all *ip_repo/rot_lut/rot_lut.xci]
if {[llength $rot_lut_ip_files] > 0} {
  remove_files $rot_lut_ip_files
}
set rot_lut_behav [file normalize [file join $script_dir .. compat rot_lut_behav.v]]
if {[file exists $rot_lut_behav]} {
  add_files -norecurse -fileset $simset $rot_lut_behav
}

set atan_lut_ip_files [get_files -quiet -all *ip_repo/atan_lut/atan_lut.xci]
if {[llength $atan_lut_ip_files] > 0} {
  remove_files $atan_lut_ip_files
}
set atan_lut_coregen_files [get_files -quiet -all *coregen/atan_lut.v]
if {[llength $atan_lut_coregen_files] > 0} {
  remove_files $atan_lut_coregen_files
}
set atan_lut_behav [file normalize [file join $script_dir .. compat atan_lut_behav.v]]
if {[file exists $atan_lut_behav]} {
  add_files -norecurse -fileset $simset $atan_lut_behav
}

if {[info exists ::env(OPENWIFI_RX_HT_POLARITY_FIX)] && $::env(OPENWIFI_RX_HT_POLARITY_FIX) ne "0"} {
  set equalizer_src_files [get_files -quiet -all *verilog/equalizer.v]
  if {[llength $equalizer_src_files] > 0} {
    remove_files $equalizer_src_files
  }
  set equalizer_ht_polarity_fix [file normalize [file join $script_dir .. compat equalizer_ht_polarity_fix.v]]
  if {![file exists $equalizer_ht_polarity_fix]} {
    error "Missing equalizer HT polarity fix: $equalizer_ht_polarity_fix"
  }
  puts "RX_MAC_JOINT_USING_EQUALIZER_HT_POLARITY_FIX"
  add_files -norecurse -fileset $simset $equalizer_ht_polarity_fix
}

set ise_unisim_dir [file normalize [file join $work_dir verilog Xilinx 12.2 ISE_DS ISE verilog src unisims]]
foreach prim {
  BUF FD FDE FDRE FDS FDSE GND INV
  LUT1 LUT2 LUT3 LUT4
  MUXCY MUXF5 MUXF6 MUXF7 MUXF8
  RAM16X1D RAM64X1S RAMB16BWER
  VCC XORCY
} {
  set prim_file [file join $ise_unisim_dir "${prim}.v"]
  if {[file exists $prim_file]} {
    add_files -norecurse -fileset $simset $prim_file
  }
}

set viterbi_behav [file normalize [file join $script_dir .. compat viterbi_v7_0_axis_behav.v]]
set viterbi_ip2024_dir ""
set use_original_viterbi_xci 0
if {[info exists ::env(OPENWIFI_VITERBI_IP_2024_DIR)]} {
  set viterbi_ip2024_dir [file normalize $::env(OPENWIFI_VITERBI_IP_2024_DIR)]
}
if {[info exists ::env(OPENWIFI_USE_ORIGINAL_VITERBI_XCI)] && $::env(OPENWIFI_USE_ORIGINAL_VITERBI_XCI) ne "0"} {
  set use_original_viterbi_xci 1
}
if {$viterbi_ip2024_dir ne ""} {
  set viterbi_ip_files [get_files -quiet -all *ip_repo/viterbi/viterbi_v7_0.xci]
  if {[llength $viterbi_ip_files] > 0} {
    remove_files $viterbi_ip_files
  }
  set viterbi_ip2024_vhd [file normalize [file join $viterbi_ip2024_dir viterbi_ip_2024 viterbi_ip_2024.gen sources_1 ip viterbi_v7_0_core sim viterbi_v7_0_core.vhd]]
  set viterbi_ip2024_wrapper [file normalize [file join $script_dir .. compat viterbi_v7_0_axis_ip2024_wrapper.v]]
  set viterbi_legacy_core [file normalize [file join $script_dir .. compat viterbi_v7_0_legacy_core.v]]
  set viterbi_behav_core [file normalize [file join $script_dir .. compat viterbi_v7_0_axis_behav_core.v]]
  if {![file exists $viterbi_ip2024_vhd]} {
    error "Missing Viterbi 2024 VHDL wrapper: $viterbi_ip2024_vhd"
  }
  if {![file exists $viterbi_ip2024_wrapper]} {
    error "Missing Viterbi 2024 Verilog wrapper: $viterbi_ip2024_wrapper"
  }
  if {[info exists ::env(OPENWIFI_VITERBI_IP2024_LEGACY_TIMING_OUTPUT)] && $::env(OPENWIFI_VITERBI_IP2024_LEGACY_TIMING_OUTPUT) ne "0"} {
    if {![file exists $viterbi_legacy_core]} {
      error "Missing legacy Viterbi core: $viterbi_legacy_core"
    }
    puts "RX_MAC_JOINT_USING_VITERBI_IP2024_LEGACY_TIMING_OUTPUT"
    add_files -norecurse -fileset $simset $viterbi_legacy_core
  }
  if {[info exists ::env(OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT)] && $::env(OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT) ne "0"} {
    if {![file exists $viterbi_behav_core]} {
      error "Missing behavior Viterbi core: $viterbi_behav_core"
    }
    puts "RX_MAC_JOINT_USING_VITERBI_IP2024_BEHAV_TIMING_OUTPUT"
    add_files -norecurse -fileset $simset $viterbi_behav_core
  }
  puts "RX_MAC_JOINT_USING_VITERBI_IP2024 $viterbi_ip2024_dir"
  add_files -norecurse -fileset $simset $viterbi_ip2024_vhd
  add_files -norecurse -fileset $simset $viterbi_ip2024_wrapper
} elseif {$use_original_viterbi_xci} {
  puts "RX_MAC_JOINT_USING_ORIGINAL_VITERBI_XCI"
} elseif {[file exists $viterbi_behav]} {
  add_files -norecurse -fileset $simset $viterbi_behav
}

set xpu_files [list \
  [file join $xpu_src xpu.v] \
  [file join $xpu_src xpu_s_axi.v] \
  [file join $xpu_src tx_on_detection.v] \
  [file join $xpu_src tx_control.v] \
  [file join $xpu_src tsf_timer.v] \
  [file join $xpu_src time_slice_gen.v] \
  [file join $xpu_src spi_command.v] \
  [file join $xpu_src spi.v] \
  [file join $xpu_src rssi.v] \
  [file join $xpu_src pkt_filter_ctl.v] \
  [file join $xpu_src phy_rx_parse.v] \
  [file join $xpu_src n_sym_len14_pkt.v] \
  [file join $xpu_src iq_rssi_to_db.v] \
  [file join $xpu_src iq_abs_avg.v] \
  [file join $xpu_src dc_rm.v] \
  [file join $xpu_src cw_exp.v] \
  [file join $xpu_src csma_ca.v] \
  [file join $xpu_src cca.v] \
]

set rx_intf_files [list \
  [file join $rx_intf_src rx_intf.v] \
  [file join $rx_intf_src rx_intf_s_axi.v] \
  [file join $rx_intf_src adc_intf.v] \
  [file join $rx_intf_src rx_iq_intf.v] \
  [file join $rx_intf_src gpio_status_rf_to_bb.v] \
  [file join $rx_intf_src byte_to_word_fcs_sn_insert.v] \
  [file join $rx_intf_src rx_intf_pl_to_m_axis.v] \
  [file join $rx_intf_src rx_intf_m_axis.v] \
]

foreach f [concat $xpu_files $rx_intf_files] {
  if {![file exists $f]} {
    error "Missing RX MAC joint source: $f"
  }
  add_files -norecurse -fileset $simset $f
}

set tb_file [file normalize [file join $script_dir .. compat openwifi_rx_mac_joint_tb.v]]
add_files -norecurse -fileset $simset $tb_file

set include_dirs [list \
  [file normalize [file join $work_dir verilog]] \
  $xpu_src \
  $rx_intf_src \
]
set_property -name "include_dirs" -value $include_dirs -objects $simset
set verilog_defines [list XPU_DISCONNECT_LED RX_INTF_DISCONNECT_LED]
if {[info exists ::env(OPENWIFI_VITERBI_IP2024_SIGNED_MAG_INPUT)] && $::env(OPENWIFI_VITERBI_IP2024_SIGNED_MAG_INPUT) ne "0"} {
  lappend verilog_defines VITERBI_IP2024_SIGNED_MAG_INPUT
}
if {[info exists ::env(OPENWIFI_VITERBI_IP2024_LEGACY_TIMING_OUTPUT)] && $::env(OPENWIFI_VITERBI_IP2024_LEGACY_TIMING_OUTPUT) ne "0"} {
  lappend verilog_defines VITERBI_IP2024_LEGACY_TIMING_OUTPUT
}
if {[info exists ::env(OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT)] && $::env(OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT) ne "0"} {
  lappend verilog_defines VITERBI_IP2024_BEHAV_TIMING_OUTPUT
}
set_property -name "verilog_define" -value $verilog_defines -objects $simset
set_property -name "top" -value "openwifi_rx_mac_joint_tb" -objects $simset

update_compile_order -fileset sim_1

set wdb_path [file normalize [file join $result_dir openwifi_rx_mac_joint.wdb]]
set_property -name "xsim.simulate.wdb" -value $wdb_path -objects $simset
set_property -name "xsim.simulate.runtime" -value "0ns" -objects $simset

launch_simulation -simset sim_1 -mode behavioral
restart
if {$log_waves ne "0"} {
  log_wave -r /*
}

set n_iq [rx_mac_count_lines $iq_file]
puts "RX_MAC_JOINT_SIM_NUM_IQ $n_iq"
puts "RX_MAC_JOINT_SIM_RUN ${sim_time_us}us"
run ${sim_time_us}us

set xsim_dir [file normalize [file join $work_dir openofdm_rx openofdm_rx.sim sim_1 behav xsim]]
rx_mac_copy_text_results $xsim_dir $result_dir

puts "RX_MAC_JOINT_SIM_XSIM_DIR $xsim_dir"
puts "RX_MAC_JOINT_SIM_WDB $wdb_path"
puts "RX_MAC_JOINT_SIM_DONE"
