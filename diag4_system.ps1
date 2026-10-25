$ErrorActionPreference = 'SilentlyContinue'

# diag4 · 系统与稳定性：管理员身份 / 内存条 / 页面文件 / 待重启 / 错误事件 / 磁盘延迟 / 运行时长

Write-Output '=== Am I admin? ==='
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Output '=== RAM modules ==='
Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel,DeviceLocator,@{n='CapGB';e={$_.Capacity/1GB}},Speed,ConfiguredClockSpeed,Manufacturer,PartNumber | Format-Table -AutoSize

Write-Output '=== Pagefile settings ==='
Get-CimInstance Win32_PageFileSetting | Format-List Name,InitialSize,MaximumSize
Get-CimInstance Win32_ComputerSystem | Select-Object AutomaticManagedPagefile | Format-List

Write-Output '=== Pending reboot ==='
Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'

Write-Output '=== Critical/Error events last 14 days (top sources) ==='
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=(Get-Date).AddDays(-14)} |
    Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 10 Count,Name | Format-Table -AutoSize

Write-Output '=== Unexpected shutdown / disk errors sample ==='
Get-WinEvent -FilterHashtable @{LogName='System'; Id=41,6008,129,153,7; StartTime=(Get-Date).AddDays(-30)} |
    Select-Object -First 8 TimeCreated,Id,ProviderName | Format-Table -AutoSize

Write-Output '=== Disk read/write latency (perf counters, 2s sample) ==='
(Get-Counter '\PhysicalDisk(*)\Avg. Disk sec/Read','\PhysicalDisk(*)\Avg. Disk sec/Write' -SampleInterval 2 -MaxSamples 1).CounterSamples |
    Where-Object { $_.InstanceName -ne '_total' } | Select-Object InstanceName,Path,CookedValue | Format-Table -AutoSize

Write-Output '=== Uptime ==='
$os = Get-CimInstance Win32_OperatingSystem
"LastBoot: $($os.LastBootUpTime)  UptimeDays: {0:N2}" -f ((Get-Date) - $os.LastBootUpTime).TotalDays

Write-Output '=== AV product detail ==='
Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct | Select-Object displayName,pathToSignedProductExe,timestamp | Format-List
