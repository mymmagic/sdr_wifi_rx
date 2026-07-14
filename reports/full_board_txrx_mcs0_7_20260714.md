# Full Board TX/RX PL Simulation

Run tag: full_board_txrx_mcs0_7_20260714_final

Scope: TX main-link joint simulation -> HT-SIG bridge stimulus -> RX + low-MAC joint simulation.

Environment:

```text
Vivado: C:\Xilinx\Vivado\2024.2\bin\vivado.bat
OPENWIFI_VITERBI_IP_2024_DIR=W:/outputs/rx_algorithm_sim/work/viterbi_ip_2024_model_license_retry_tb84_20260712
OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT=1
OPENWIFI_RX_HT_POLARITY_FIX unset
TX sim: 180us
RX sim: 260us
RX waves: True
```

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

Artifacts:

- TX results: tx/mcs*/
- RX stimuli: stimuli/mcs*_rx_stimulus.txt
- RX results: rx/mcs*/
- Vivado logs: logs/
- Machine-readable summaries: full_board_txrx_summary.csv, full_board_txrx_summary.json
