$ErrorActionPreference = 'SilentlyContinue'

# diag1 · 硬件与资源概览：物理磁盘健康 / 分区空间 / 内存与页面文件 / 内存占用 Top 进程

Write-Output '=== Physical Disks ==='
Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,@{n='SizeGB';e={[math]::Round($_.Size/1GB)}} | Format-Table -AutoSize

Write-Output '=== Drive Space ==='
Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object DeviceID,VolumeName,@{n='UsedGB';e={[math]::Round(($_.Size-$_.FreeSpace)/1GB,1)}},@{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,1)}},@{n='TotalGB';e={[math]::Round($_.Size/1GB,1)}} | Format-Table -AutoSize

Write-Output '=== Top 15 Processes by Memory ==='
Get-Process | Sort-Object WS -Descending | Select-Object -First 15 Name,@{n='MemMB';e={[math]::Round($_.WS/1MB)}} | Format-Table -AutoSize

Write-Output '=== Memory Summary ==='
$os = Get-CimInstance Win32_OperatingSystem
"TotalGB: {0:N1}  FreeGB: {1:N1}" -f ($os.TotalVisibleMemorySize/1MB), ($os.FreePhysicalMemory/1MB)
$pf = Get-CimInstance Win32_PageFileUsage
$pf | Select-Object Name,@{n='AllocatedMB';e={$_.AllocatedBaseSize}},@{n='CurrentUsageMB';e={$_.CurrentUsage}} | Format-Table -AutoSize
