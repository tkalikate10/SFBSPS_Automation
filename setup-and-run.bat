@echo off
setlocal enabledelayedexpansion
title BSPS Currency Rate Automation - Setup and Run
color 0A

echo ============================================================
echo   BSPS Currency Rate Automation - One Click Setup
echo ============================================================
echo.

:: ---------------------------------------------------------------
:: STEP 1: Check Node.js
:: ---------------------------------------------------------------
echo [Step 1/5] Checking Node.js installation...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo   Node.js NOT found. Installing via winget...
    echo.
    winget install -e --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo.
        echo   ERROR: winget failed. Please install Node.js LTS manually from https://nodejs.org
        echo   After installing, close this window and run this script again.
        pause
        exit /b 1
    )
    echo.
    echo   Node.js installed. You may need to CLOSE and REOPEN this window
    echo   for the 'node' command to be available.
    echo   If the next step fails, close this window and double-click setup-and-run.bat again.
    echo.
    :: Refresh PATH for current session
    set "PATH=%ProgramFiles%\nodejs;%PATH%"
) else (
    for /f "tokens=*" %%v in ('node -v') do echo   Node.js found: %%v
)
echo.

:: ---------------------------------------------------------------
:: STEP 2: Check npm dependencies
:: ---------------------------------------------------------------
echo [Step 2/5] Checking npm dependencies...
cd /d "%~dp0"
if not exist "node_modules\playwright" (
    echo   Installing npm dependencies...
    call npm install --registry=https://registry.npmjs.org/
    if %errorlevel% neq 0 (
        echo   ERROR: npm install failed. Check your internet connection.
        pause
        exit /b 1
    )
    echo   Dependencies installed.
) else (
    echo   Dependencies already installed.
)
echo.

:: ---------------------------------------------------------------
:: STEP 3: Check Playwright Chromium browser
:: ---------------------------------------------------------------
echo [Step 3/5] Checking Playwright Chromium browser...
set "PW_BROWSERS=%LOCALAPPDATA%\ms-playwright"
if not exist "%PW_BROWSERS%\chromium-*" (
    echo   Downloading Chromium browser (~180 MB)...
    call npx playwright install chromium
    if %errorlevel% neq 0 (
        echo   ERROR: Playwright browser install failed.
        pause
        exit /b 1
    )
    echo   Chromium installed.
) else (
    echo   Chromium browser already installed.
)
echo.

:: ---------------------------------------------------------------
:: STEP 4: Ask user for schedule time
:: ---------------------------------------------------------------
echo.
echo ============================================================
echo   ALL SETUP CHECKS PASSED
echo ============================================================
echo.
echo   Press any key when you are ready to enter the schedule time.
echo.
pause
echo.
echo ============================================================
echo   SCHEDULE DAILY REFRESH TIME
echo ============================================================
echo.
echo   Type the time you want the currency rates to update daily.
echo   Format : HH:MM   (24-hour clock)
echo   Example: 08:00   09:00   17:00
echo.
echo   Press Enter WITHOUT typing anything to skip scheduling.
echo.
for /f "delims=" %%T in ('powershell -NoProfile -Command "Read-Host \"  Enter daily schedule time (HH:MM)\""') do set SCHEDULE_TIME=%%T
echo.

:: ---------------------------------------------------------------
:: STEP 5: Run the scraper now
:: ---------------------------------------------------------------
echo [Step 4/5] Running OANDA currency rate scraper...
echo.
cd /d "%~dp0"
call node .\scripts\update-oanda-rates.js
if %errorlevel% neq 0 (
    echo.
    echo   ERROR: Scraper failed. Check the output above for details.
    pause
    exit /b 1
)
echo.
echo   Currency rates updated successfully.
echo.

:: ---------------------------------------------------------------
:: STEP 5: Register daily task if user provided a time
:: ---------------------------------------------------------------
if not "!SCHEDULE_TIME!"=="" (
    echo [Step 5/5] Registering daily task at !SCHEDULE_TIME!...
    powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\register-oanda-task.ps1" -StartTime "!SCHEDULE_TIME!"
    if %errorlevel% neq 0 (
        echo.
        echo   WARNING: Task registration failed. You may need to run this as Administrator.
        echo   The scraper still ran successfully above.
    ) else (
        echo   Daily task registered at !SCHEDULE_TIME!.
    )
) else (
    echo [Step 5/5] Scheduling skipped. You can register it later with:
    echo   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-oanda-task.ps1 -StartTime "08:00"
)

echo.
echo ============================================================
echo   All done!
echo ============================================================
echo.
pause
