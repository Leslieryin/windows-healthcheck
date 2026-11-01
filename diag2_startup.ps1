$ErrorActionPreference = 'SilentlyContinue'

# diag2 · 启动项与服务：电源计划 / 自启项 / 非微软自动服务 / 待装更新 / 电池健康

Write-Output '=== Power Plan ==='
powercfg /getactivescheme
powercfg /list

Write-Output '=== Startup (approved) ==='
Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location | Format-Table -Wrap -AutoSize

Write-Output '=== Startup Apps (TaskManager list) ==='
# StartupApproved：值首字节 02=启用 03=禁用；翻译成人话并排除 PS* 元数据属性
foreach ($hive in 'HKCU:', 'HKLM:') {
    $k = "$hive\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    $props = Get-ItemProperty $k -ErrorAction SilentlyContinue
    if ($props) {
        "[$k]"
        $props.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
            $b = $_.Value
            if ($b -is [byte[]] -and $b.Length -gt 0) {
                $state = if ($b[0] -band 1) { 'Disabled' } else { 'Enabled' }
                "  {0} = {1}" -f $_.Name, $state
            } else { "  {0} = {1}" -f $_.Name, $_.Value }
        }
    }
}

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
