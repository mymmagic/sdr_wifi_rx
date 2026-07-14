param(
  [int[]]$McsList = @(0, 1, 2, 3, 4, 5, 6, 7),
  [string]$RunTag = "",
  [int]$TxSimUs = 180,
  [int]$RxSimUs = 260,
  [switch]$NoWaves
)

$ErrorActionPreference = "Stop"

$workspace = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\.."))
$workspaceW = "W:"
$vivado = "C:\Xilinx\Vivado\2024.2\bin\vivado.bat"

$hwRootW = "$workspaceW/outputs/vivado_board_sim/openwifi-hw-git"
$rxWorkDirW = "$workspaceW/outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_rx"
$txScriptW = "$workspaceW/outputs/tx_algorithm_sim/scripts/run_openwifi_tx_main_joint_vivado.tcl"
$rxScriptW = "$workspaceW/outputs/rx_algorithm_sim/scripts/run_openwifi_rx_mac_joint_vivado.tcl"
$stimGen = Join-Path $workspace "outputs\rx_algorithm_sim\scripts\generate_rx_ht_loopback_stimulus.py"

$txMemMcs0W = "$workspaceW/outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_tx/unit_test/test_vec/tx_intf.mem"
$txMemHtW = "$workspaceW/outputs/vivado_board_sim/openwifi-hw-git/ip/openofdm_tx/unit_test/test_vec/ht_tx_intf_mem_mcs7_gi1_aggr0_byte100.mem"

if ($RunTag -eq "") {
  $RunTag = "full_board_txrx_mcs0_7_" + (Get-Date -Format "yyyyMMdd_HHmmss")
}

$runRoot = Join-Path $workspace "outputs\tx_rx_loopback_sim\full_board_runs\$RunTag"
$txRoot = Join-Path $runRoot "tx"
$rxRoot = Join-Path $runRoot "rx"
$stimRoot = Join-Path $runRoot "stimuli"
$logRoot = Join-Path $runRoot "logs"
New-Item -ItemType Directory -Force -Path $txRoot, $rxRoot, $stimRoot, $logRoot | Out-Null

function Convert-ToWPath([string]$Path) {
  $full = [System.IO.Path]::GetFullPath($Path)
  $rootFull = [System.IO.Path]::GetFullPath($workspace)
  if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside workspace and cannot be converted to W: $Path"
  }
  $rel = $full.Substring($rootFull.Length).TrimStart("\", "/")
  return ($workspaceW + "/" + ($rel -replace "\\", "/"))
}

function Read-SummaryValue([string]$Path, [string]$Key) {
  if (-not (Test-Path -LiteralPath $Path)) {
    return ""
  }
  $line = Get-Content -LiteralPath $Path | Where-Object { $_ -match ("^" + [regex]::Escape($Key) + "[ ,]") } | Select-Object -First 1
  if ($null -eq $line) {
    return ""
  }
  if ($line -match "^[^,]+,") {
    return ($line -split ",", 2)[1].Trim()
  }
  return ($line -split "\s+", 2)[1].Trim()
}

if (-not (Test-Path -LiteralPath $vivado)) {
  throw "Missing Vivado: $vivado"
}
if (-not (Test-Path -LiteralPath $stimGen)) {
  throw "Missing stimulus generator: $stimGen"
}

$env:XILINXD_LICENSE_FILE = "C:\Xilinx\Vivado_IP.lic;C:\Xilinx\License.lic;C:\Xilinx\vivadoLicence.lic;C:\Xilinx\vivado_lic2037.lic;C:\Xilinx\Vivado_license2037.lic"
$env:OPENWIFI_VITERBI_IP_2024_DIR = "$workspaceW/outputs/rx_algorithm_sim/work/viterbi_ip_2024_model_license_retry_tb84_20260712"
$env:OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT = "1"
Remove-Item Env:\OPENWIFI_RX_HT_POLARITY_FIX -ErrorAction SilentlyContinue

$rows = @()

foreach ($mcs in $McsList) {
  if ($mcs -lt 0 -or $mcs -gt 7) {
    throw "Unsupported MCS: $mcs"
  }

  $mcsHex = "{0:X1}" -f $mcs
  $slvReg17 = "32'h000${mcsHex}C064"
  $caseName = "ht_mcs${mcs}_gi1_aggr0_byte100_full_board"
  $txMemW = if ($mcs -eq 0) { $txMemMcs0W } else { $txMemHtW }

  $txDir = Join-Path $txRoot ("mcs{0}" -f $mcs)
  $rxDir = Join-Path $rxRoot ("mcs{0}" -f $mcs)
  $stimFile = Join-Path $stimRoot ("mcs{0}_rx_stimulus.txt" -f $mcs)
  $txLog = Join-Path $logRoot ("mcs{0}_tx_vivado.log" -f $mcs)
  $rxLog = Join-Path $logRoot ("mcs{0}_rx_vivado.log" -f $mcs)
  New-Item -ItemType Directory -Force -Path $txDir, $rxDir | Out-Null

  $txDirW = Convert-ToWPath $txDir
  $rxDirW = Convert-ToWPath $rxDir
  $stimFileW = Convert-ToWPath $stimFile

  Write-Host "=== MCS$mcs TX simulation ==="
  & $vivado -mode batch -nojournal -nolog `
    -source $txScriptW `
    -tclargs $hwRootW $txMemW $txDirW $TxSimUs $caseName 15 100 $slvReg17 220000 *> $txLog
  if ($LASTEXITCODE -ne 0) {
    throw "Vivado TX failed for MCS$mcs. See $txLog"
  }

  $txSummary = Join-Path $txDir "tx_main_joint_summary.txt"
  $txCoreIq = Join-Path $txDir "tx_main_joint_core_iq.csv"
  if (-not (Test-Path -LiteralPath $txCoreIq)) {
    throw "Missing TX core IQ for MCS${mcs}: $txCoreIq"
  }

  Write-Host "=== MCS$mcs stimulus bridge ==="
  & py $stimGen --tx-core-iq $txCoreIq --out $stimFile --pre-zeros 100 --post-zeros 200
  if ($LASTEXITCODE -ne 0) {
    throw "Stimulus generation failed for MCS$mcs"
  }

  Write-Host "=== MCS$mcs RX simulation ==="
  $logWaves = if ($NoWaves) { "0" } else { "1" }
  & $vivado -mode batch -nojournal -nolog `
    -source $rxScriptW `
    -tclargs $rxWorkDirW $stimFileW $rxDirW $RxSimUs zed_fmcs2 100 $stimFileW $logWaves *> $rxLog
  if ($LASTEXITCODE -ne 0) {
    throw "Vivado RX failed for MCS$mcs. See $rxLog"
  }

  $rxSummary = Join-Path $rxDir "rx_mac_joint_summary.txt"
  $row = [pscustomobject]@{
    mcs = $mcs
    tx_case = $caseName
    tx_slv_reg17 = ("0x000{0}c064" -f $mcsHex.ToLower())
    tx_pass = Read-SummaryValue $txSummary "pass"
    tx_phy_done_count = Read-SummaryValue $txSummary "phy_done_count"
    tx_core_iq_accept_count = Read-SummaryValue $txSummary "core_iq_accept_count"
    stimulus = $stimFile
    rx_status = Read-SummaryValue $rxSummary "status"
    rx_fcs_ok_cnt = Read-SummaryValue $rxSummary "fcs_ok_cnt"
    rx_axis_tlast_cnt = Read-SummaryValue $rxSummary "axis_tlast_cnt"
    tx_result_dir = $txDir
    rx_result_dir = $rxDir
    tx_log = $txLog
    rx_log = $rxLog
  }
  $rows += $row
  $row | Format-List | Out-String | Write-Host
}

$csvPath = Join-Path $runRoot "full_board_txrx_summary.csv"
$jsonPath = Join-Path $runRoot "full_board_txrx_summary.json"
$mdPath = Join-Path $runRoot "full_board_txrx_summary.md"
$rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
$rows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$allPass = $true
foreach ($row in $rows) {
  if ($row.tx_pass -ne "1" -or $row.rx_status -ne "PASS" -or $row.rx_fcs_ok_cnt -ne "1" -or $row.rx_axis_tlast_cnt -ne "1") {
    $allPass = $false
  }
}

$lines = @()
$lines += "# Full Board TX/RX PL Simulation"
$lines += ""
$lines += "Run tag: $RunTag"
$lines += ""
$lines += "Scope: TX main-link joint simulation -> HT-SIG bridge stimulus -> RX + low-MAC joint simulation."
$lines += ""
$lines += "Environment:"
$lines += ""
$lines += '```text'
$lines += "Vivado: $vivado"
$lines += "OPENWIFI_VITERBI_IP_2024_DIR=$($env:OPENWIFI_VITERBI_IP_2024_DIR)"
$lines += "OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT=$($env:OPENWIFI_VITERBI_IP2024_BEHAV_TIMING_OUTPUT)"
$lines += "OPENWIFI_RX_HT_POLARITY_FIX unset"
$lines += "TX sim: ${TxSimUs}us"
$lines += "RX sim: ${RxSimUs}us"
$lines += "RX waves: $(-not $NoWaves)"
$lines += '```'
$lines += ""
$lines += "Overall status: " + $(if ($allPass) { "PASS" } else { "FAIL" })
$lines += ""
$lines += "| MCS | TX pass | TX done | TX IQ | RX status | RX FCS OK | RX tlast |"
$lines += "| --- | --- | --- | --- | --- | --- | --- |"
foreach ($row in $rows) {
  $lines += "| $($row.mcs) | $($row.tx_pass) | $($row.tx_phy_done_count) | $($row.tx_core_iq_accept_count) | $($row.rx_status) | $($row.rx_fcs_ok_cnt) | $($row.rx_axis_tlast_cnt) |"
}
$lines += ""
$lines += "Artifacts:"
$lines += ""
$lines += "- TX results: tx/mcs*/"
$lines += "- RX stimuli: stimuli/mcs*_rx_stimulus.txt"
$lines += "- RX results: rx/mcs*/"
$lines += "- Vivado logs: logs/"
$lines += "- Machine-readable summaries: full_board_txrx_summary.csv, full_board_txrx_summary.json"
$lines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host "FULL_BOARD_TXRX_RUN_ROOT $runRoot"
Write-Host "FULL_BOARD_TXRX_SUMMARY $mdPath"
if ($allPass) {
  Write-Host "FULL_BOARD_TXRX_STATUS PASS"
  exit 0
}

Write-Host "FULL_BOARD_TXRX_STATUS FAIL"
exit 1
