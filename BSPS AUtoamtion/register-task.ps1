param (
    [Parameter(Mandatory=$true)]
    [string]$StartTime,
    
    [Parameter(Mandatory=$true)]
    [string]$TaskName,

    [string]$PythonExe = "python.exe", # Path to your python.exe
    [string]$ScriptPath = "C:\BSPS\BSPS AUtoamtion\app_sf_Automation.py" # Full path to your .py file
)

# 1. Define the Action (Runs Python directly)
$Action = New-ScheduledTaskAction -Execute $PythonExe -Argument "`"$ScriptPath`""

# 2. Define the Trigger (Daily at specified time)
$Trigger = New-ScheduledTaskTrigger -Daily -At $StartTime

# 3. Settings (Wake PC if sleeping; Start as soon as possible if missed)
$Settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable

# 4. Register the Task
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Force

Write-Host "Task '$TaskName' registered successfully for daily run at $StartTime." -ForegroundColor Green