param(
    # 要统计错误事件的日志提供者。NVIDIA 驱动是 nvlddmkm；AMD 为 amdgpu 驱动事件源，
    # 也可以加上虚拟网卡驱动（MuMuVMMNetLwf / VBoxNetLwf）排查模拟器网络问题。
    [string[]]$Providers = @('nvlddmkm'),
    [int]$Days = 14
)
$ErrorActionPreference = 'SilentlyContinue'

# diag5 · 显卡/驱动错误专项：指定 Provider 的事件样本、按 Id 计数、Schannel 错误

$start = (Get-Date).AddDays(-$Days)

foreach ($provider in $Providers) {
    Write-Output "=== $provider error samples ($Days days) ==="
    Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName=$provider; StartTime=$start} |
        Select-Object -First 6 TimeCreated,Id,LevelDisplayName,Message | Format-List

    Write-Output "=== $provider event count by Id ==="
    Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName=$provider; StartTime=$start} |
        Group-Object Id | Select-Object Count,Name | Format-Table -AutoSize
}

Write-Output '=== Schannel error sample (last 3 days) ==='
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Schannel'; Level=2; StartTime=(Get-Date).AddDays(-3)} |
    Select-Object -First 2 TimeCreated,Message | Format-List
