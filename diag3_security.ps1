param(
    # 关注的厂商计划任务名模式（通配符），按需改成你机器上关心的软件
    [string[]]$TaskPatterns = @('*Update*', '*Launcher*', '*Agent*')
)
$ErrorActionPreference = 'SilentlyContinue'

# diag3 · 安全与系统设置：杀软注册 / Run 键 / 休眠与快速启动 / HAGS / Defender / 缓存体积

Write-Output '=== Registered Antivirus (SecurityCenter2) ==='
Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct | Select-Object displayName,productState | Format-Table -AutoSize

Write-Output '=== HKCU/HKLM Run keys ==='
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' | Format-List
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' | Format-List

Write-Output '=== Hibernation / Fast Startup ==='
powercfg /a

Write-Output '=== HAGS (hardware GPU scheduling) ==='
$hags = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name HwSchMode
"HwSchMode = $($hags.HwSchMode)  (2=on, 1=off)"

Write-Output '=== Defender status ==='
Get-MpComputerStatus | Select-Object AMServiceEnabled,RealTimeProtectionEnabled,AntivirusEnabled,AntivirusSignatureLastUpdated,QuickScanEndTime | Format-List

Write-Output '=== Temp/Cache sizes ==='
foreach ($p in @("$env:TEMP", 'C:\Windows\Temp', 'C:\Windows\SoftwareDistribution\Download')) {
    $s = (Get-ChildItem $p -Recurse -Force | Measure-Object Length -Sum).Sum
    "{0}  :  {1:N1} MB" -f $p, ($s/1MB)
}

Write-Output '=== Memory compression / SysMain ==='
Get-Service MemCompression,SysMain | Select-Object Name,Status,StartType | Format-Table -AutoSize

Write-Output "=== Vendor scheduled tasks (patterns: $($TaskPatterns -join ', ')) ==="
Get-ScheduledTask -TaskName $TaskPatterns | Where-Object { $_.State -ne 'Disabled' } | Select-Object TaskName,State | Format-Table -AutoSize

Write-Output '=== Storage Sense ==='
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' | Out-String

Write-Output '=== Game Mode ==='
$gm = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameBar' -Name AutoGameModeEnabled,AllowAutoGameMode
"AutoGameModeEnabled = $($gm.AutoGameModeEnabled)"

Write-Output '=== Visual effects ==='
$ve = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
"VisualFXSetting = $($ve.VisualFXSetting) (0=custom,1=best appearance,2=best performance,3=let windows decide)"
