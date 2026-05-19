param (
    [Parameter(Mandatory=$true)]
    [string]$StartTime,
    
    [Parameter(Mandatory=$true)]
    [string]$TaskName,

    [string]$PythonExe = "python.exe",
    [string]$ScriptPath = "C:\BSPS\BSPS AUtoamtion\app_sf_Automation.py"
)

# 1. Define the Action
$Action = New-ScheduledTaskAction -Execute $PythonExe -Argument "`"$ScriptPath`""

# 2. Define the Trigger (Daily at your specified time)
$Trigger = New-ScheduledTaskTrigger -Daily -At $StartTime

# 3. Define Settings with "Catch-up" logic
# -StartWhenAvailable: This checks for missed runs and fires them immediately after login.
# -AllowStartIfOnBatteries: Ensures it runs even if the laptop isn't plugged in at that moment.
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# 4. Register as your current user (No Admin required)
# This will save the task to your local user profile.
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Force

Write-Host "Task '$TaskName' is now registered with 'Start When Available' enabled." -ForegroundColor Green
Write-Host "It will capture any missed runs (like 12 PM) and trigger them once you login (like 1 PM)." -ForegroundColor Cyan