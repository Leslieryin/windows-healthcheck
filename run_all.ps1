# run_all.ps1 · 一键体检：依次运行 diag1~diag5（diag6 为定向排查，按需手动跑），
# 全部输出同时写入 体检报告-<日期>.txt，方便留档对比。
param(
    [string[]]$GpuProviders = @('nvlddmkm')
)
$ErrorActionPreference = 'SilentlyContinue'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$report = Join-Path $here ("体检报告-{0:yyyyMMdd-HHmm}.txt" -f (Get-Date))

# ---------------------------------------------------------------- 输出与落盘
# 不用 Tee-Object：它写出的文件在 PowerShell 5.1 下是 UTF-16LE，
# 用 git diff / 很多编辑器打开都是乱码，留档对比时很不方便。
# 这里自己实现 tee，统一写 UTF-8（无 BOM）。
function Write-Utf8 {
    param([string]$Text, [string]$Path, [switch]$Append)
    $enc = New-Object System.Text.UTF8Encoding($false)
    if ($Append) {
        [System.IO.File]::AppendAllText($Path, $Text + "`r`n", $enc)
    } else {
        [System.IO.File]::WriteAllText($Path, $Text + "`r`n", $enc)
    }
}

function Tee-Report {
    param(
        [Parameter(ValueFromPipeline = $true)] $InputObject,
        [string]$Path,
        [switch]$Append
    )
    begin {
        $enc = New-Object System.Text.UTF8Encoding($false)
        if (-not $Append) { [System.IO.File]::WriteAllText($Path, '', $enc) }
    }
    process {
        $line = if ($null -eq $InputObject) { '' } else { [string]$InputObject }
        [System.IO.File]::AppendAllText($Path, $line + "`r`n", $enc)
        Write-Output $InputObject
    }
}

Write-Utf8 ("=== Windows 一键体检  $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===") $report

Write-Utf8 "`n`n########## diag1_hardware ##########" $report -Append
& (Join-Path $here 'diag1_hardware.ps1') | Out-String -Stream | Tee-Report -Path $report -Append

Write-Utf8 "`n`n########## diag2_startup ##########" $report -Append
& (Join-Path $here 'diag2_startup.ps1') | Out-String -Stream | Tee-Report -Path $report -Append

Write-Utf8 "`n`n########## diag3_security ##########" $report -Append
& (Join-Path $here 'diag3_security.ps1') | Out-String -Stream | Tee-Report -Path $report -Append

Write-Utf8 "`n`n########## diag4_system ##########" $report -Append
& (Join-Path $here 'diag4_system.ps1') | Out-String -Stream | Tee-Report -Path $report -Append

Write-Utf8 "`n`n########## diag5_gpu_errors ##########" $report -Append
& (Join-Path $here 'diag5_gpu_errors.ps1') -Providers $GpuProviders | Out-String -Stream | Tee-Report -Path $report -Append

"`n`n报告已保存: $report"
