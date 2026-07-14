# RX 节点日志生成说明

整理日期：2026-07-13

本文说明 `results/mcs*/` 和 `rerun/mcs7_rx_joint_rerun_160us/` 里的 RX 对比节点是怎么产生的。

## 结论

这些节点不是原始 RTL 自带的独立输出口，也不是人工从波形里抄出来的。它们由联合仿真 testbench 在 Vivado xsim 运行时，通过 `$fwrite` 对 RTL 内部信号和顶层输出事件进行采样生成。

采样 testbench：

```text
sim/compat/openwifi_rx_mac_joint_tb.v
```

仿真运行脚本：

```text
sim/scripts/run_openwifi_rx_mac_joint_vivado.tcl
```

MCS7 溯源复跑输入：

```text
stimuli/mcs7_rx_stimulus.txt
```

MCS7 溯源复跑输出：

```text
rerun/mcs7_rx_joint_rerun_160us/
```

## 节点文件来源

`rx_mac_joint_summary.txt`

- 由 `openwifi_rx_mac_joint_tb.v` 在仿真结束前写出。
- 统计 `phy_header_cnt`、`fcs_ok_cnt`、`axis_tlast_cnt` 等计数。
- PASS 条件为 FCS OK、filter pass、AXI 输出和 `tlast` 均出现。

`rx_mac_joint_demod.csv`

- 当 `openofdm_rx_i.state == 5'd12` 且 `demod_out_strobe` 有效时写出。
- 采样 RTL 解调节点：
  - `demod_out`
  - `demod_soft_bits`
  - `cons_i_delayed`
  - `cons_q_delayed`
  - `abs_cons_i`
  - `abs_cons_q`
  - `bits`
  - `bits_delay1`
  - `bits_delay2`
  - CSI/LLR 相关地址和值
- `data_symbol = data_demod_count / 52`。
- `carrier_idx = data_demod_count % 52`。
- MCS7 问题定位时，就是用这个文件按 DATA symbol 和 carrier index 对齐 TX 侧调制期望硬判决位。

`rx_mac_joint_phy_bits.csv`

- 当 deinterleave、Viterbi、descramble、bit/byte 输出任一级 strobe 有效时写出。
- 采样节点包括：
  - `deinterleave_erase_out_strobe`
  - `deinterleave_erase_out`
  - `conv_decoder_out_stb`
  - `conv_decoder_out`
  - `descramble_out_strobe`
  - `descramble_out`
  - `bit_in_stb`
  - `bit_in`
  - `byte_out_strobe`
  - `byte_out`

`rx_mac_joint_ctrl.csv`

- 用于跨模块对齐。
- 在 RX DATA 状态、OFDM 输入、equalizer 输出、demod、deinterleave、Viterbi、byte、FCS 等关键事件发生时写出。
- 采样节点包括：
  - RX state
  - `num_ofdm_symbol`
  - `ht_data_decoder_ready`
  - `ofdm_in_stb`
  - `eq_out_stb_delayed`
  - `ofdm_symbol_eq_out_pulse`
  - `rate`
  - `len`
  - `num_bits_to_decode`
  - `n_ofdm_sym`
  - `n_bit_in_last_sym`
  - 各级 strobe

`rx_mac_joint_m_axis.csv`

- 当 `m00_axis_tvalid` 有效时写出。
- 采样 RX 最终上送出口：
  - `m00_axis_tdata`
  - `m00_axis_tlast`
  - `m00_axis_tstrb`

`rx_mac_joint_events.csv`

- 采样 MAC/RX 接口事件：
  - FC
  - addr1/addr2/addr3
  - FCS
  - filter pass/block
  - RX interface state
  - PS/DMA 相关计数

## 算法期望值来源

`algorithm_m/` 下的 `.m` 文件是反向整理出来的算法参考模型和单模块验证脚本，例如：

```text
algorithm_m/verify_openofdm_rx_demodulate_model.m
algorithm_m/verify_openofdm_rx_deinterleave_model.m
algorithm_m/verify_openofdm_rx_descramble_model.m
algorithm_m/verify_openofdm_rx_crc32_model.m
```

这些脚本用于解释和复现单模块算法行为，生成 expected vector 或 trace。

MCS7 整帧定位时的对比口径是：

```text
TX joint 调制侧期望 DATA hard bits
  对齐到 DATA symbol / 52 data carriers
RTL rx_mac_joint_demod.csv
  读取 demod_out / bits_delay 等实际解调节点
逐 symbol、逐 carrier、逐 bit 比较
```

因此当时能得到：

```text
MCS7 DATA symbol 0: 0/312 mismatch
MCS7 DATA symbol 1: 0/312 mismatch
MCS7 DATA symbol 2: 0/312 mismatch
MCS7 DATA symbol 3: 104/312 mismatch
```

再对 DATA symbol 3 做 180 度星座翻转检查后 mismatch 变为 0，从而定位到 HT DATA pilot polarity 表相位错位。

## 波形来源

`.wdb` 由 `run_openwifi_rx_mac_joint_vivado.tcl` 设置：

```text
log_wave -r /*
xsim.simulate.wdb = openwifi_rx_mac_joint.wdb
```

所以 `.wdb` 和上述 CSV/TXT 来自同一次 xsim 仿真。CSV 中的 `time_ns` 可以和 Vivado 波形时间轴对齐。
