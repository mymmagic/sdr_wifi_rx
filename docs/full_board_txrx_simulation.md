# Full Board TX/RX PL Simulation

Date: 2026-07-14

## Scope

This run covers the PL-side end-to-end OpenWiFi path used in the local Vivado simulations:

```text
TX main-link joint simulation
-> generated HT loopback RX stimulus
-> RX + low-MAC joint simulation
-> AXI-stream receive output
```

It does not include a PS/Linux boot, RF hardware, ADC/DAC hardware, driver traffic, or a complete live MAC stack.

## Run

Script:

```text
sim/scripts/run_full_board_tx_rx_mcs_sweep.ps1
```

Original local run directory:

```text
W:/outputs/tx_rx_loopback_sim/full_board_runs/full_board_txrx_mcs0_7_20260714_final
```

Equivalent command:

```powershell
powershell -ExecutionPolicy Bypass -File W:/outputs/tx_rx_loopback_sim/scripts/run_full_board_tx_rx_mcs_sweep.ps1 -McsList 0,1,2,3,4,5,6,7 -RunTag full_board_txrx_mcs0_7_20260714_final -TxSimUs 180 -RxSimUs 260
```

## Environment

```text
Vivado: C:\Xilinx\Vivado\2024.2\bin\vivado.bat
OPENWIFI_VITERBI_IP_2024_DIR=W:/outputs/rx_algorithm_sim/work/viterbi_ip_2024_model_license_retry_tb84_20260712
OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT=1
OPENWIFI_RX_HT_POLARITY_FIX unset
```

The final run uses the source-level patched `equalizer.v` in the original OpenWiFi RTL tree.

## Result

Overall status: PASS

| MCS | TX pass | TX done | TX IQ | RX status | RX FCS OK | RX tlast |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 1 | 1 | 3095 | PASS | 1 | 1 |
| 1 | 1 | 1 | 1943 | PASS | 1 | 1 |
| 2 | 1 | 1 | 1511 | PASS | 1 | 1 |
| 3 | 1 | 1 | 1367 | PASS | 1 | 1 |
| 4 | 1 | 1 | 1151 | PASS | 1 | 1 |
| 5 | 1 | 1 | 1079 | PASS | 1 | 1 |
| 6 | 1 | 1 | 1007 | PASS | 1 | 1 |
| 7 | 1 | 1 | 1007 | PASS | 1 | 1 |

## Archived Lightweight Files

```text
reports/full_board_txrx_mcs0_7_20260714.md
manifests/full_board_txrx_mcs0_7_20260714_summary.csv
manifests/full_board_txrx_mcs0_7_20260714_summary.json
sim/scripts/run_full_board_tx_rx_mcs_sweep.ps1
```

## Local Waveforms

The full local run contains logs, TX outputs, RX stimuli, RX outputs, and Vivado waveforms. It has 189 files and is about 297 MB.

Waveforms are under:

```text
W:/outputs/tx_rx_loopback_sim/full_board_runs/full_board_txrx_mcs0_7_20260714_final/tx/mcs*/openwifi_tx_main_joint.wdb
W:/outputs/tx_rx_loopback_sim/full_board_runs/full_board_txrx_mcs0_7_20260714_final/rx/mcs*/openwifi_rx_mac_joint.wdb
```

The large waveform directory is intentionally kept local unless a full waveform upload is required.
