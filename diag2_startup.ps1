$ErrorActionPreference = 'SilentlyContinue'

# diag2 · 启动项与服务：电源计划 / 自启项 / 非微软自动服务 / 待装更新 / 电池健康

Write-Output '=== Power Plan ==='
powercfg /getactivescheme
powercfg /list

Write-Output '=== Startup (approved) ==='
Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location | Format-Table -Wrap -AutoSize

Write-Output '=== Startup Apps (TaskManager list) ==='
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' | Format-List
Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' | Format-List

Write-Output '=== Non-Microsoft running services (auto) ==='
Get-CimInstance Win32_Service | Where-Object { $_.State -eq 'Running' -and $_.PathName -notlike '*\Windows\*' } | Select-Object Name,DisplayName,StartMode | Format-Table -AutoSize

Write-Output '=== Windows Update pending ==='
$session = New-Object -ComObject Microsoft.Update.Session
$searcher = $session.CreateUpdateSearcher()
$result = $searcher.Search("IsInstalled=0 and IsHidden=0")
"Pending updates: $($result.Updates.Count)"
$result.Updates | ForEach-Object { $_.Title }

Write-Output '=== Battery ==='
Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData | Select-Object DesignedCapacity | Format-List
Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity | Select-Object FullChargedCapacity | Format-List
