# RX MCS0-7 仿真溯源包

整理日期：2026-07-13

这个目录只收敛“最终通过”的 RX HT MCS0-7 主链路仿真，不包含早期失败探索目录。  
最终结论：当前 clean loopback、100B、HT short-GI、non-aggregate 条件下，RX 从 IQ/sample 输入到 AXI-stream 上送出口，MCS0 到 MCS7 全部 PASS。

## 快速入口

最终结果总表：

`reports/rx_ht_mcs0_7_sourcefix_sweep.md`

根因和源码修复：

`reports/rx_ht_pilot_polarity_mcs0_mcs7_validation.md`

完整文件索引：

`reports/rx_handoff_file_inventory.md`

RX 节点日志生成说明：

`docs/rx_node_generation.md`

逐 MCS 溯源链：

`manifests/provenance_chain.csv`

已整理文件 SHA256：

`manifests/file_hashes.csv`

GitHub 上传说明：

`GITHUB_UPLOAD.md`

大波形 `.wdb` 副本、原路径和 SHA256：

`manifests/waveform_index.csv`

## GitHub 上传包

本目录已经按独立 GitHub 仓库整理。`.wdb` 波形文件建议通过 Git LFS 上传，规则见：

```text
.gitattributes
GITHUB_UPLOAD.md
```

## 目录结构

```text
algorithm_m/     MATLAB 算法/反向模型和验证脚本
docs/            节点日志生成、对比口径等说明
manifests/       溯源 CSV/JSON、文件哈希、波形索引
reports/         最终报告和根因报告
results/         MCS0-7 的 RX summary/CSV 节点
rtl/             本次相关 Verilog/RTL 快照、equalizer 修复补丁和备份
sim/             Vivado TCL、testbench、兼容仿真模型、激励生成脚本
stimuli/         MCS0-7 最终 RX 输入激励
tx_sources/      MCS0-7 对应 TX joint 输出来源：core IQ、summary、events
waveforms/       MCS0-7 的 openwifi_rx_mac_joint.wdb 波形副本
rerun/           用本溯源包复跑 MCS7 的结果和 Vivado 日志
```

## 一条链路怎么看

以任意 MCS 为例，溯源链是：

```text
tx_sources/mcsX/tx_main_joint_core_iq.csv
  -> sim/scripts/generate_rx_ht_loopback_stimulus.py
  -> stimuli/mcsX_rx_stimulus.txt
  -> sim/scripts/run_openwifi_rx_mac_joint_vivado.tcl
  -> results/mcsX/rx_mac_joint_summary.txt
  -> waveforms/mcsX_openwifi_rx_mac_joint.wdb
  -> 原始/副本 waveform 对照: manifests/waveform_index.csv
```

`provenance_chain.csv` 里把每个 MCS 的原始路径、整理后路径、FCS 结果、AXI tlast 结果和 WDB 路径串在了一行里。

## 关键源码关系

最终生效的 RTL 修复是原工程的：

`rtl/equalizer.v`

对应原始位置：

`outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx/verilog/equalizer.v`

备份文件：

`rtl/equalizer.v.bak_ht_polarity_20260713`

补丁记录：

`rtl/equalizer_ht_pilot_polarity_fix.patch`

注意：`sim/testbenches/equalizer_ht_polarity_fix_validation_only.v` 是当时用于旁路验证的仿真副本。最终 MCS0-7 PASS 使用的是原工程 patched `equalizer.v`，没有打开 `OPENWIFI_RX_HT_POLARITY_FIX`。

## 通过标准

每个 MCS 的 RX summary 都满足：

```text
phy_header_cnt 1
fcs_ok_cnt 1
axis_tlast_cnt 1
status PASS
```

这说明仿真已经覆盖到：

```text
IQ/sample input
-> sync_short/sync_long
-> FFT
-> equalizer
-> demod
-> deinterleave
-> Viterbi
-> descramble
-> bytes/FCS
-> filter
-> rx_intf
-> AXI-stream tlast
```

## 仿真环境

Vivado:

```text
C:\Xilinx\Vivado\2024.2\bin\vivado.bat
```

通过时使用的关键环境变量：

```text
OPENWIFI_RX_HT_POLARITY_FIX unset
OPENWIFI_VITERBI_IP_2024_DIR=W:/outputs/rx_algorithm_sim/work/viterbi_ip_2024_model_license_retry_tb84_20260712
OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT=1
```

许可变量当时设置为：

```text
XILINXD_LICENSE_FILE=C:\Xilinx\Vivado_IP.lic;C:\Xilinx\License.lic;C:\Xilinx\vivadoLicence.lic;C:\Xilinx\vivado_lic2037.lic;C:\Xilinx\Vivado_license2037.lic
```

## 溯源包复跑验证

2026-07-13 已用本溯源包路径复跑 MCS7，一次通过。

使用的溯源包文件：

```text
sim/scripts/run_openwifi_rx_mac_joint_vivado.tcl
stimuli/mcs7_rx_stimulus.txt
```

复跑输出：

```text
rerun/mcs7_rx_joint_rerun_160us/rx_mac_joint_summary.txt
rerun/mcs7_rx_joint_rerun_160us/openwifi_rx_mac_joint.wdb
rerun/mcs7_rx_joint_rerun_160us.vivado.log
```

复跑结果：

```text
fcs_ok_cnt 1
axis_tlast_cnt 1
status PASS
```

为了让 copied TCL 在溯源包位置可直接使用，已补齐它依赖的原始相对目录：

```text
sim/compat/
vivado_board_sim/scripts/vivado_unix_compat.tcl
```

复跑边界：

```text
本溯源包提供脚本、激励、compat 仿真文件、结果和波形；
Vivado 工程创建仍使用原工程目录：
outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx
Viterbi 2024 IP model 仍使用：
outputs/rx_algorithm_sim/work/viterbi_ip_2024_model_license_retry_tb84_20260712
```

如果需要把这个目录单独拷到另一台机器离线复跑，还需要把上述原工程目录和 Viterbi IP model 一起纳入 standalone 包。

## 波形说明

`.wdb` 文件已经按 MCS 复制到：

```text
waveforms/mcs0_openwifi_rx_mac_joint.wdb
waveforms/mcs1_openwifi_rx_mac_joint.wdb
...
waveforms/mcs7_openwifi_rx_mac_joint.wdb
```

原始路径、副本路径、大小和 SHA256 请看：

`manifests/waveform_index.csv`

其中 `hashes_match=True` 表示副本和原始 `.wdb` 完全一致。

## 边界

这个溯源包覆盖的是 PL 侧 Verilog 仿真的 RX 主链路。它不包含真实板级 RF/ADC 实物输入、AXI DMA 到 PS、Linux 驱动或上层 MAC 协议栈联调。
