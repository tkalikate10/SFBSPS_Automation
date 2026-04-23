param(
    [string]$ProjectPath = "C:\BSPS",
    [string]$LogDirectory = "C:\BSPS\logs"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $ProjectPath)) {
    throw "Project path not found: $ProjectPath"
}

if (-not (Test-Path -Path $LogDirectory)) {
    New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $LogDirectory "oanda_update_$timestamp.log"

Push-Location $ProjectPath
try {
    "[$(Get-Date -Format o)] Starting OANDA rate update" | Out-File -FilePath $logFile -Encoding utf8

    $command = "node .\scripts\update-oanda-rates.js"
    cmd.exe /c "$command >> `"$logFile`" 2>&1"
    $exitCode = $LASTEXITCODE

    "[$(Get-Date -Format o)] ExitCode=$exitCode" | Out-File -FilePath $logFile -Encoding utf8 -Append

    if ($exitCode -ne 0) {
        throw "OANDA update failed with exit code $exitCode. Check log: $logFile"
    }
}
finally {
    Pop-Location
}
