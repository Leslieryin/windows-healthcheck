# run_all.ps1 · 一键体检：依次运行 diag1~diag5（diag6 为定向排查，按需手动跑），
# 全部输出同时写入 体检报告-<日期>.txt，方便留档对比。
param(
    [string[]]$GpuProviders = @('nvlddmkm')
)
$ErrorActionPreference = 'SilentlyContinue'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$report = Join-Path $here ("体检报告-{0:yyyyMMdd-HHmm}.txt" -f (Get-Date))

"=== Windows 一键体检  $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===" | Tee-Object -FilePath $report

"`n`n########## diag1_hardware ##########" | Tee-Object -FilePath $report -Append
& (Join-Path $here 'diag1_hardware.ps1') | Tee-Object -FilePath $report -Append

"`n`n########## diag2_startup ##########" | Tee-Object -FilePath $report -Append
& (Join-Path $here 'diag2_startup.ps1') | Tee-Object -FilePath $report -Append

"`n`n########## diag3_security ##########" | Tee-Object -FilePath $report -Append
& (Join-Path $here 'diag3_security.ps1') | Tee-Object -FilePath $report -Append

"`n`n########## diag4_system ##########" | Tee-Object -FilePath $report -Append
& (Join-Path $here 'diag4_system.ps1') | Tee-Object -FilePath $report -Append

"`n`n########## diag5_gpu_errors ##########" | Tee-Object -FilePath $report -Append
& (Join-Path $here 'diag5_gpu_errors.ps1') -Providers $GpuProviders | Tee-Object -FilePath $report -Append

"`n`n报告已保存: $report"
