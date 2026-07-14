# RX HT MCS0-7 Source-Fix Sweep

Date: 2026-07-13

## Scope

This sweep validates the integrated RX source fix in:

`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/equalizer.v`

The simulation-only equalizer replacement switch was not used:

```text
OPENWIFI_RX_HT_POLARITY_FIX unset
OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT=1
```

All cases use a 100-byte HT, non-aggregate, short-GI packet.

## Stimulus

- MCS0 and MCS7 use the already validated source-fix loopback stimuli.
- MCS1, MCS2, MCS3, MCS4, MCS5, and MCS6 were generated from the TX joint
  simulation by changing `tx_slv_reg17` to the requested MCS value.
- The same validated bridge operation was applied to the two HT-SIG OFDM
  symbols: data subcarriers are negated in frequency domain, pilots are left
  unchanged.

## Results

| MCS | RX result | `phy_header_cnt` | `fcs_ok_cnt` | `axis_tlast_cnt` | Waveform |
|---:|---|---:|---:|---:|---|
| 0 | PASS | 1 | 1 | 1 | `outputs/tx_rx_loopback_sim/results/rx_joint_mcs0_htsigfix_sourcefix_240us/openwifi_rx_mac_joint.wdb` |
| 1 | PASS | 1 | 1 | 1 | `outputs/tx_rx_loopback_sim/results/rx_joint_mcs1_htsigfix_sourcefix_240us/openwifi_rx_mac_joint.wdb` |
| 2 | PASS | 1 | 1 | 1 | `outputs/tx_rx_loopback_sim/results/rx_joint_mcs2_htsigfix_sourcefix_240us/openwifi_rx_mac_joint.wdb` |
| 3 | PASS | 1 | 1 | 1 | `outputs/tx_rx_loopback_sim/results/rx_joint_mcs3_htsigfix_sourcefix_240us/openwifi_rx_mac_joint.wdb` |
| 4 | PASS | 1 | 1 | 1 | `outputs/tx_rx_loopback_sim/results/rx_joint_mcs4_htsigfix_sourcefix_240us/openwifi_rx_mac_joint.wdb` |
| 5 | PASS | 1 | 1 | 1 | `outputs/tx_rx_loopback_sim/results/rx_joint_mcs5_htsigfix_sourcefix_240us/openwifi_rx_mac_joint.wdb` |
| 6 | PASS | 1 | 1 | 1 | `outputs/tx_rx_loopback_sim/results/rx_joint_mcs6_htsigfix_sourcefix_240us/openwifi_rx_mac_joint.wdb` |
| 7 | PASS | 1 | 1 | 1 | `outputs/tx_rx_loopback_sim/results/rx_joint_mcs7_htsigfix_sourcefix_160us/openwifi_rx_mac_joint.wdb` |

## Summary

The RX HT main path passes MCS0 through MCS7 for the current clean 100-byte
loopback cases. This covers BPSK, QPSK, 16QAM, and 64QAM paths, including the
different puncturing/deinterleaving configurations used by these MCS values.

