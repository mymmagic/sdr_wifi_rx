# RX Handoff File Inventory

Date: 2026-07-13

This is a curated index for the current RX bring-up state. It does not move or
duplicate source files. Large waveform files are referenced in place.

## Final Status

The integrated RX source path passes HT MCS0 through MCS7 for the current clean
100-byte loopback cases.

Primary result report:

`outputs/rx_algorithm_sim/reports/rx_ht_mcs0_7_sourcefix_sweep.md`

Root-cause and source-fix report:

`outputs/rx_algorithm_sim/reports/rx_ht_pilot_polarity_mcs0_mcs7_validation.md`

## Source Change

Patched original RTL:

`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/equalizer.v`

Backup of the pre-fix RTL:

`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/equalizer.v.bak_ht_polarity_20260713`

Patch record:

`outputs/rx_algorithm_sim/patches/equalizer_ht_pilot_polarity_fix.patch`

Validation-only equalizer copy, no longer needed for final source-fix runs:

`outputs/rx_algorithm_sim/compat/equalizer_ht_polarity_fix.v`

## Simulation Files

### RX Joint Simulation

Main RX + XPU + RX interface testbench:

`outputs/rx_algorithm_sim/compat/openwifi_rx_mac_joint_tb.v`

Vivado batch runner:

`outputs/rx_algorithm_sim/scripts/run_openwifi_rx_mac_joint_vivado.tcl`

Important compatibility/simulation models:

`outputs/rx_algorithm_sim/compat/rot_lut_behav.v`  
`outputs/rx_algorithm_sim/compat/atan_lut_behav.v`  
`outputs/rx_algorithm_sim/compat/viterbi_v7_0_axis_ip2024_wrapper.v`  
`outputs/rx_algorithm_sim/compat/viterbi_v7_0_axis_behav_core.v`  
`outputs/rx_algorithm_sim/compat/viterbi_v7_0_legacy_core.v`

Vivado 2024 Viterbi IP model directory:

`outputs/rx_algorithm_sim/work/viterbi_ip_2024_model_license_retry_tb84_20260712`

Runtime settings used by the passing RX joint simulations:

```text
OPENWIFI_RX_HT_POLARITY_FIX unset
OPENWIFI_VITERBI_IP_2024_DIR=W:/outputs/rx_algorithm_sim/work/viterbi_ip_2024_model_license_retry_tb84_20260712
OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT=1
```

### TX Stimulus Generation

TX joint testbench:

`outputs/tx_algorithm_sim/compat/openwifi_tx_main_joint_tb.v`

Vivado batch runner:

`outputs/tx_algorithm_sim/scripts/run_openwifi_tx_main_joint_vivado.tcl`

MCS1 to MCS6 stimuli were generated from TX joint simulation, then converted
to RX input format with the same validated HT-SIG data-bin frequency-domain
fix used during the RX loopback debug.

### Final RX Result Directories

Each directory contains:

- `rx_mac_joint_summary.txt`: pass/fail counters
- `rx_mac_joint_events.csv`: state and interface events
- `rx_mac_joint_bytes.csv`: decoded PHY bytes
- `rx_mac_joint_phy_bits.csv`: deinterleave/Viterbi/descramble/byte nodes
- `rx_mac_joint_demod.csv`: DATA demod hard/soft-bit nodes when enabled
- `rx_mac_joint_m_axis.csv`: AXI-stream output words
- `openwifi_rx_mac_joint.wdb`: Vivado waveform

```text
outputs/tx_rx_loopback_sim/results/rx_joint_mcs0_htsigfix_sourcefix_240us
outputs/tx_rx_loopback_sim/results/rx_joint_mcs1_htsigfix_sourcefix_240us
outputs/tx_rx_loopback_sim/results/rx_joint_mcs2_htsigfix_sourcefix_240us
outputs/tx_rx_loopback_sim/results/rx_joint_mcs3_htsigfix_sourcefix_240us
outputs/tx_rx_loopback_sim/results/rx_joint_mcs4_htsigfix_sourcefix_240us
outputs/tx_rx_loopback_sim/results/rx_joint_mcs5_htsigfix_sourcefix_240us
outputs/tx_rx_loopback_sim/results/rx_joint_mcs6_htsigfix_sourcefix_240us
outputs/tx_rx_loopback_sim/results/rx_joint_mcs7_htsigfix_sourcefix_160us
```

Machine-readable MCS0-7 summary:

`outputs/tx_rx_loopback_sim/results/mcs_sweep_logs/rx_mcs0_7_sourcefix_summary.json`

Vivado logs for generated MCS2 to MCS6 TX/RX runs:

`outputs/tx_rx_loopback_sim/results/mcs_sweep_logs`

## RX Verilog Source Files

### RX PHY Top And Control

`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/openofdm_rx.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/dot11.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/dot11_setting_agent.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/openofdm_rx_s_axi.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/common_defs.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/common_params.v`

### RX Detection, CFO/Phase, FFT Input Path

`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/sync_short.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/sync_long.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/phase.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/rotate.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/rot_after_fft.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/power_trigger.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/signal_watchdog.v`

### RX Equalize/Demod/Decode/Bytes/FCS

`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/equalizer.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/demodulate.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/deinterleave.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/ofdm_decoder.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/viterbi.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/descramble.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/bits_to_bytes.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/crc32.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/ht_sig_crc.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/phy_len_calculation.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/rate_to_idx.v`

### RX Math/Memory/Delay Helpers

`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/calc_mean.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/complex_mult.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/complex_to_mag.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/complex_to_mag_sq.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/divider.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/dpram.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/delayT.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/fifo_sample_delay.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/mv_avg.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/mv_avg_dual_ch.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/running_sum.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/running_sum_dual_ch.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/stage_mult.v`

## RX Interface / XPU Verilog Files

The RX joint simulation includes the PHY plus low-MAC/filter and PL-to-AXI
output path.

### RX Interface

`outputs/vivado_board_sim/openwifi-hw-git/ip/rx_intf/src/rx_intf.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/rx_intf/src/rx_intf_s_axi.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/rx_intf/src/adc_intf.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/rx_intf/src/rx_iq_intf.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/rx_intf/src/gpio_status_rf_to_bb.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/rx_intf/src/byte_to_word_fcs_sn_insert.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/rx_intf/src/rx_intf_pl_to_m_axis.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/rx_intf/src/rx_intf_m_axis.v`

### XPU / Filter / RSSI / CCA Support

`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/xpu.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/xpu_s_axi.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/phy_rx_parse.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/pkt_filter_ctl.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/rssi.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/iq_rssi_to_db.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/iq_abs_avg.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/dc_rm.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/cca.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/csma_ca.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/cw_exp.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/n_sym_len14_pkt.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/time_slice_gen.v`  
`outputs/vivado_board_sim/openwifi-hw-git/ip/xpu/src/tsf_timer.v`

## Algorithm / Reverse-Model Files

### MATLAB Algorithm Models

TX/OFDM algorithm reverse models:

`outputs/openwifi_dot11_tx_ht_joint_model.m`  
`outputs/openwifi_dot11_tx_joint_model.m`  
`outputs/openwifi_ifft64_fixed_model.m`  
`outputs/openwifi_tx_modulation_model.m`  
`outputs/openwifi_punc_interlv_model.m`  
`outputs/openwifi_convenc_model.m`  
`outputs/openwifi_dot11_scrambler_model.m`  
`outputs/openwifi_crc32_tx_model.m`  
`outputs/openwifi_ht_sig_crc_model.m`  
`outputs/openwifi_dot11_pilot_map_model.m`  
`outputs/openwifi_n_sym_len14_model.m`

RX algorithm reverse/verification models:

`outputs/openofdm_rx_power_trigger_model.m`  
`outputs/openofdm_rx_moving_avg_model.m`  
`outputs/openofdm_rx_delay_sample_model.m`  
`outputs/verify_openofdm_rx_sync_short_joint.m`  
`outputs/verify_openofdm_rx_top_nodes.m`  
`outputs/verify_openofdm_rx_rotate_model.m`  
`outputs/verify_openofdm_rx_phase_model.m`  
`outputs/verify_openofdm_rx_demodulate_model.m`  
`outputs/verify_openofdm_rx_deinterleave_model.m`  
`outputs/verify_openofdm_rx_descramble_model.m`  
`outputs/verify_openofdm_rx_bits_to_bytes_model.m`  
`outputs/verify_openofdm_rx_crc32_model.m`  
`outputs/verify_openofdm_rx_viterbi_model.m`  
`outputs/verify_openofdm_rx_ht_sig_crc_model.m`

### Python RX Decode Reference

`outputs/rx_algorithm_sim/pydecode/decode.py`  
`outputs/rx_algorithm_sim/pydecode/condense.py`  
`outputs/rx_algorithm_sim/pydecode/test.py`  
`outputs/rx_algorithm_sim/pydecode/gen_deinter_lut.py`  
`outputs/rx_algorithm_sim/pydecode/gen_rot_lut.py`  
`outputs/rx_algorithm_sim/pydecode/gen_atan_lut.py`

## Notes

- The final RX source-fix runs use the original patched `equalizer.v`; they do
  not depend on the simulation-only `equalizer_ht_polarity_fix.v`.
- The passing RX joint simulations verify the PL-side RX path from IQ/sample
  input through PHY decode, FCS, filtering, RX interface, and AXI-stream
  `tlast`.
- PS/Linux/DMA driver software is outside this Verilog simulation boundary.
- Direct raw output from the Vivado 2024 Viterbi IP wrapper is still a separate
  timing-compatibility topic. The validated RX path uses the behavior-timing
  compatible output mode while instantiating the 2024 IP model.

