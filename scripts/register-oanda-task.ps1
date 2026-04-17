param(
    [string]$TaskName = "Daily OANDA Currency Refresh",
    [string]$StartTime = "08:00",
    [string]$ProjectPath = "C:\log-analysis-agent",
    [string]$RunnerPath = "C:\log-analysis-agent\scripts\run-oanda-update.ps1",
    [ValidateSet("Limited", "Highest")]
    [string]$RunLevel = "Limited"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $RunnerPath)) {
    throw "Runner script not found: $RunnerPath"
}

$timeParts = $StartTime.Split(':')
if ($timeParts.Count -ne 2) {
    throw "StartTime must be in HH:mm format, example: 08:00"
}

$hour = [int]$timeParts[0]
$minute = [int]$timeParts[1]
$startDateTime = (Get-Date).Date.AddHours($hour).AddMinutes($minute)

if ($startDateTime -lt (Get-Date)) {
    $startDateTime = $startDateTime.AddDays(1)
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$RunnerPath`" -ProjectPath `"$ProjectPath`""

$trigger = New-ScheduledTaskTrigger -Daily -At $startDateTime
$userId = if ($env:USERDOMAIN) { "$($env:USERDOMAIN)\$($env:USERNAME)" } else { $env:USERNAME }
$principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel $RunLevel
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

$task = New-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings

Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null

Write-Output "Registered task '$TaskName' at $($startDateTime.ToString('yyyy-MM-dd HH:mm')) with RunLevel=$RunLevel"
