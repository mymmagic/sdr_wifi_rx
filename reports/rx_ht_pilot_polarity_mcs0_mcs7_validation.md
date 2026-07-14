# RX HT Pilot Polarity Validation

Date: 2026-07-13

## Scope

This report records the validation and source integration of the openwifi RX HT
DATA pilot polarity issue. The candidate RTL change was first tested through a
copied equalizer model under `outputs/rx_algorithm_sim/compat`, then applied to
the original openwifi RX source after it passed MCS7 and MCS0 checks.

## Root Cause

The RX equalizer HT DATA pilot polarity sequence in:

`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/equalizer.v`

uses:

```verilog
localparam HT_PILOT_POLARITY =
    127'b1110000000111000100111010110100000101010111101001000011000110101001100111110010010100010111001101110111111011011001011000010001;
```

Compared against the TX pilot LFSR sequence, this table is phase-shifted. The
candidate aligned table is:

```verilog
localparam HT_PILOT_POLARITY =
    127'b0010100010111001101110111111011011001011000010001111000000011100010011101011010000010101011110100100001100011010100110011111001;
```

This is equivalent to rotating the existing expected RX HT DATA pilot polarity
sequence by +49 entries.

## Simulation-Only Files

- `outputs/rx_algorithm_sim/compat/equalizer_ht_polarity_fix.v`
  - Copy of original `equalizer.v` with only `HT_PILOT_POLARITY` changed.
- `outputs/rx_algorithm_sim/scripts/run_openwifi_rx_mac_joint_vivado.tcl`
  - Added opt-in env switch `OPENWIFI_RX_HT_POLARITY_FIX=1`.
  - Default behavior remains unchanged.
- `outputs/rx_algorithm_sim/compat/openwifi_rx_mac_joint_tb.v`
  - Added debug CSV `rx_mac_joint_demod.csv` for DATA demod hard/soft bits.

## Source Fix

Patched source:

`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/equalizer.v`

Backup of the pre-fix source:

`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/equalizer.v.bak_ht_polarity_20260713`

Only the `HT_PILOT_POLARITY` table was changed.

## Key Evidence

### MCS7 Before RX Table Fix

Stimulus:

`outputs/tx_rx_loopback_sim/stim/baseline_current_mcs7_core_htsigfix.txt`

Result:

`outputs/tx_rx_loopback_sim/results/rx_joint_mcs7_htsigfix_demod_probe_160us`

DATA demod hard-bit comparison against TX modulation bits:

```text
sym 0: bitMis=0/312
sym 1: bitMis=0/312
sym 2: bitMis=0/312
sym 3: bitMis=104/312
```

For DATA symbol 3, applying a 180-degree constellation inversion
(`tx_bits ^ 6'h09`, flipping I and Q sign bits) gives:

```text
negIQ_180: bitMis=0, rowMis=0
```

That proves the last DATA symbol is seen by RX with a full 180-degree polarity
error, not a deinterleave, puncture, or Viterbi mapping error.

### MCS7 After RX Table Fix

Command condition:

```text
OPENWIFI_RX_HT_POLARITY_FIX=1
OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT=1
```

Result:

`outputs/tx_rx_loopback_sim/results/rx_joint_mcs7_htsigfix_eqpolfix_demod_probe_160us`

Summary:

```text
fcs_ok_cnt 1
axis_tlast_cnt 1
status PASS
```

DATA demod hard-bit comparison:

```text
sym 0: bitMis=0/312
sym 1: bitMis=0/312
sym 2: bitMis=0/312
sym 3: bitMis=0/312
TOTAL bitMis=0/1248
```

Tail bytes:

```text
... 20 77 65 20 74 72 65 61 00 00 00 00 35 48 05 0f
```

### MCS7 After Source Integration

Command condition:

```text
OPENWIFI_RX_HT_POLARITY_FIX unset
OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT=1
```

Result:

`outputs/tx_rx_loopback_sim/results/rx_joint_mcs7_htsigfix_sourcefix_160us`

Summary:

```text
fcs_ok_cnt 1
axis_tlast_cnt 1
status PASS
```

### MCS0 Regression Check

Stimulus:

`outputs/tx_rx_loopback_sim/stim/tx_mcs0_100B_core_pre100_post200_htsig_data_bins_neg.txt`

Result:

`outputs/tx_rx_loopback_sim/results/rx_joint_mcs0_htsigfix_eqpolfix_240us`

Summary:

```text
fcs_ok_cnt 1
axis_tlast_cnt 1
status PASS
```

The same RX HT polarity table fix also removes the previously required
hand-made DATA-symbol polarity workaround for MCS0.

### MCS0 After Source Integration

Command condition:

```text
OPENWIFI_RX_HT_POLARITY_FIX unset
OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT=1
```

Result:

`outputs/tx_rx_loopback_sim/results/rx_joint_mcs0_htsigfix_sourcefix_240us`

Summary:

```text
fcs_ok_cnt 1
axis_tlast_cnt 1
status PASS
```

## Notes

The direct raw output of the generated Vivado 2024 Viterbi IP wrapper is not
yet timing-equivalent to the legacy openwifi Viterbi interface. The validated
PASS runs use the existing behavior-timing compatibility output while still
instantiating/logging the 2024 IP. The equalizer polarity root cause is
independent of that wrapper timing issue.
