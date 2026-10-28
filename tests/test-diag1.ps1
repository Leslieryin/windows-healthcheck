#Requires -Version 5.1
<#
.SYNOPSIS
    diag1_hardware.ps1 的测试：注入假硬件数据，验证它算得对、且不会崩。

.DESCRIPTION
    这个脚本没有纯函数，全是直接取数的管道，所以没法单独调某个函数来测。
    做法是用同名函数遮蔽真实 cmdlet（PowerShell 里函数优先于 cmdlet），
    然后 dot-source 被测脚本——它会拿到我们喂的假数据。

    不需要 Pester，任何 PowerShell 5.1+ 都能跑。

    测的重点是「装得下也算得对」：
    - 容量换算（2TB → 2048 GB）写错分母不会报错，只会静默显示错的数字
    - Top 15 是否真的截断
    - 内存汇总的 KB→GB 换算（这个最容易写成 /1GB）
    - 什么都取不到时不该崩
#>

$ErrorActionPreference = 'Stop'

$script:Pass = 0
$script:Fail = 0
$script:Failures = New-Object System.Collections.ArrayList

function Assert-True {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        $script:Pass++
        Write-Host "  PASS  $Name" -ForegroundColor Green
    } else {
        $script:Fail++
        [void]$script:Failures.Add($Name)
        $msg = "  FAIL  $Name"
        if ($Detail) { $msg += "  [$Detail]" }
        Write-Host $msg -ForegroundColor Red
    }
}

# ---------------------------------------------------------------- 假数据源
# 每个测试直接改这些变量，然后调 Invoke-Diag
$script:FakeDisks      = @()
$script:FakeLogical    = @()
$script:FakeProcs      = @()
$script:FakeOS         = $null
$script:FakePageFile   = @()

# ---------------------------------------------------------------- 遮蔽真实命令
function Get-PhysicalDisk { $script:FakeDisks }
function Get-Process { $script:FakeProcs }

function Get-CimInstance {
    param([string]$ClassName, [string]$Filter)
    switch ($ClassName) {
        'Win32_LogicalDisk'     { $script:FakeLogical }
        'Win32_OperatingSystem' { $script:FakeOS }
        'Win32_PageFileUsage'   { $script:FakePageFile }
        default                 { }
    }
}

# PowerShell 5.1 的 Join-Path 只接受两个路径参数，不能连写
$DiagPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'diag1_hardware.ps1'
if (-not (Test-Path $DiagPath)) {
    Write-Host "找不到被测脚本: $DiagPath" -ForegroundColor Red
    exit 1
}

function Invoke-Diag {
    # 被测脚本会把 $ErrorActionPreference 改成 SilentlyContinue，跑完要还原
    $saved = $ErrorActionPreference
    try {
        . $DiagPath 6>&1 | Out-String
    } finally {
        $ErrorActionPreference = $saved
    }
}

# ================================================================ 测试开始
Write-Host ""
Write-Host "[磁盘容量换算]" -ForegroundColor Cyan
$script:FakeDisks = @(
    [pscustomobject]@{ FriendlyName = 'DiskA'; MediaType = 'SSD'; HealthStatus = 'Healthy'
                       OperationalStatus = 'OK'; Size = 2199023255552 }      # 2 TB
    [pscustomobject]@{ FriendlyName = 'DiskB'; MediaType = 'HDD'; HealthStatus = 'Warning'
                       OperationalStatus = 'OK'; Size = 536870912000 }       # 500 GB
)
$out = Invoke-Diag
Assert-True '2TB 换算成 2048 GB' ($out -match 'DiskA.*?2048') `
    '分母写错（比如 /1MB）时会显示 2097152，不报错'
# 不要求尾部空格：PS 7 的 Format-Table 会裁掉行尾空白，PS 5.1 会保留，
# 写成 '\s500\s' 会在 PS 7 下假失败
Assert-True '500GB 换算成 500 GB' ($out -match 'DiskB.*?500')
Assert-True 'Warning 健康状态原样透传' ($out -match 'Warning')
Assert-True '四节标题都在' (
    $out -match '=== Physical Disks ===' -and
    $out -match '=== Drive Space ===' -and
    $out -match '=== Top 15 Processes by Memory ===' -and
    $out -match '=== Memory Summary ==='
)

Write-Host ""
Write-Host "[分区空间换算]" -ForegroundColor Cyan
# 500GB 总容量，已用 300GB，剩 200GB
$script:FakeLogical = @(
    [pscustomobject]@{
        DeviceID = 'C:'; VolumeName = 'System'
        Size = 536870912000; FreeSpace = 214748364800
    }
)
$out = Invoke-Diag
$driveRow = @(($out -split "`r?`n") | Where-Object { $_ -match '^C:\s' })[0]
Assert-True '分区盘符出现' ([bool]$driveRow) '没找到以 C: 开头的行'
# 脚本用 Round(...,1)，整数结果显示为 300 而非 300.0
if ($driveRow) {
    $n300 = $driveRow -match '300'
    $n200 = $driveRow -match '200'
    $n500 = $driveRow -match '500'
} else {
    $n300 = $n200 = $n500 = $false
}
Assert-True '已用 300 / 剩余 200 / 总计 500' ($n300 -and $n200 -and $n500) `
    "实际行=[$driveRow] 300=$n300 200=$n200 500=$n500"

Write-Host ""
Write-Host "[进程 Top 15 截断]" -ForegroundColor Cyan
$script:FakeProcs = 1..20 | ForEach-Object {
    [pscustomobject]@{ Name = "Proc$('{0:D2}' -f $_)"; WS = (1000 - $_ * 10) * 1MB }
}
$out = Invoke-Diag
$procLines = ($out -split "`r?`n") | Where-Object { $_ -match '^Proc\d\d' }
Assert-True '给了 20 个进程，只输出 15 行' ($procLines.Count -eq 15) `
    "实际 $($procLines.Count) 行"
Assert-True '按内存降序：第一个是 Proc01' ($procLines[0] -match 'Proc01')

Write-Host ""
Write-Host "[内存汇总 KB→GB 换算]" -ForegroundColor Cyan
# Win32_OperatingSystem 的内存字段单位是 KB
$script:FakeOS = [pscustomobject]@{
    TotalVisibleMemorySize = 33554432   # 32 GB
    FreePhysicalMemory     = 8388608    # 8 GB
}
$script:FakePageFile = @(
    [pscustomobject]@{ Name = 'C:\pagefile.sys'; AllocatedBaseSize = 10240; CurrentUsage = 115 }
)
$out = Invoke-Diag
Assert-True '32GB 显示为 TotalGB: 32.0' ($out -match 'TotalGB:\s*32\.0') `
    '写成 /1GB 会得到 32768.0'
Assert-True '8GB 显示为 FreeGB: 8.0' ($out -match 'FreeGB:\s*8\.0')
Assert-True '页面文件出现在输出里' ($out -match 'pagefile\.sys')

Write-Host ""
Write-Host "[取不到数据时不崩]" -ForegroundColor Cyan
$script:FakeDisks = @()
$script:FakeLogical = @()
$script:FakeProcs = @()
$script:FakeOS = $null
$script:FakePageFile = @()
$threw = $false
try { $null = Invoke-Diag } catch { $threw = $true }
Assert-True '全空数据不抛异常' (-not $threw) `
    '脚本靠 SilentlyContinue 兜底，缺硬件时应该少几行而不是崩掉'

# ================================================================ 汇总
Write-Host ""
$total = $script:Pass + $script:Fail
if ($script:Fail -eq 0) {
    Write-Host "结果：$($script:Pass) 通过 / 0 失败" -ForegroundColor Green
} else {
    Write-Host "结果：$($script:Pass) 通过 / $($script:Fail) 失败" -ForegroundColor Red
    Write-Host "失败项：" -ForegroundColor Red
    foreach ($f in $script:Failures) { Write-Host "  - $f" -ForegroundColor Red }
}
Write-Host ""
exit $(if ($script:Fail -eq 0) { 0 } else { 1 })
