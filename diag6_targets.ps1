param(
    # 要专项排查的进程/计划任务名模式。示例：国产软件常驻、更新器、卸载残留。
    # 用法：.\diag6_targets.ps1 -Names 'SDXHelper','*Quark*','*Norton*'
    [string[]]$Names = @('*Updater*', '*Update*')
)
$ErrorActionPreference = 'SilentlyContinue'

# diag6 · 定向排查：你点名的进程 / 计划任务 / 卸载残留，逐项给出路径与详情

foreach ($n in $Names) {
    Write-Output "=== Processes matching '$n' ==="
    Get-Process -Name $n | Select-Object -First 5 Name,Id,Path | Format-Table -AutoSize

    Write-Output "=== Scheduled tasks matching '$n' ==="
    $tasks = Get-ScheduledTask -TaskName $n
    $tasks | Select-Object TaskName,TaskPath,State | Format-Table -AutoSize
    $tasks | ForEach-Object {
        "  [$($_.TaskName)] Actions:"
        $_.Actions | ForEach-Object { "    $($_.Execute) $($_.Arguments)" }
    }

    Write-Output "=== Installed products matching '$n' ==="
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' |
        Where-Object { $_.DisplayName -like $n } |
        Select-Object DisplayName,DisplayVersion,Publisher | Format-Table -AutoSize
}
