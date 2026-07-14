# GitHub 上传说明

这个目录已经整理成一个可以独立提交的 GitHub 溯源包，内容覆盖：

- MATLAB 算法/反向模型：`algorithm_m/`
- RTL 快照、补丁和备份：`rtl/`
- Vivado 联合仿真脚本、testbench、compat 模型：`sim/`
- MCS0-7 RX 激励：`stimuli/`
- MCS0-7 仿真结果节点：`results/`
- MCS0-7 波形副本：`waveforms/`
- MCS7 溯源复跑结果：`rerun/`
- 文件哈希和链路索引：`manifests/`

## 大文件策略

`.wdb` 波形文件使用 Git LFS：

```bash
git lfs ls-files
```

上传到 GitHub 前，请确认目标仓库允许 Git LFS。当前波形单文件均小于 GitHub 100MB 单文件硬限制，但用 LFS 更适合后续管理。

## 推送命令

如果目标仓库已经存在：

```bash
git remote add origin https://github.com/<owner>/<repo>.git
git push -u origin main
```

如果已经添加过 remote：

```bash
git remote set-url origin https://github.com/<owner>/<repo>.git
git push -u origin main
```

## 边界

本仓库是 RX HT MCS0-7 仿真溯源包，不是完整 OpenWiFi 上游工程镜像。复跑时仍依赖 README 中记录的原始 openofdm_rx 工程目录和 Vivado Viterbi IP model。
