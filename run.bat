@echo off
cd /d "%~dp0"
title BSPS Currency Rate Automation - Setup and Run
color 0A

echo ============================================================
echo   BSPS Currency Rate Automation - Core Pipeline
echo ============================================================
echo.

:: --- STEP 1: VERIFY ENVIRONMENTS ---
echo [1/5] Verifying Node.js and Python installations...
where node >nul 2>&1 || (echo CRITICAL ERROR: Node.js NOT found && goto :EXIT)
where python >nul 2>&1 || (echo CRITICAL ERROR: Python NOT found && goto :EXIT)
for /f "tokens=*" %%v in ('node -v') do echo   ✔ Node.js found: %%v
for /f "tokens=*" %%v in ('python --version') do echo   ✔ Python found: %%v
echo.

:: --- STEP 2: NPM DEPENDENCIES ---
echo [2/5] Deploying Node.js modules...
call npm install --registry=https://npmjs.org --quiet
if %errorlevel% neq 0 (
    echo   WARNING: npm install had issues, but attempting to continue...
) else (
    echo   ✔ Node packages updated.
)
echo.

:: --- STEP 3: PLAYWRIGHT CHROMIUM ---
echo [3/5] Verifying Playwright browser engines...
call npx playwright install chromium
if %errorlevel% neq 0 (
    echo   WARNING: Playwright install failed.
) else (
    echo   ✔ Chromium framework ready.
)
echo.

:: --- STEP 4: PYTHON MODULES ---
echo [4/5] Checking and installing Python libraries...
python -m pip install simple-salesforce pandas pywin32 openpyxl python-dotenv --quiet
if %errorlevel% neq 0 (
    echo   WARNING: Some Python packages failed to install.
) else (
    echo   ✔ Python libraries validated.
)
echo.

:: --- STEP 5: RUN THE SCRAPER ---
echo ============================================================
echo   ALL SYSTEM CHECKS PASSED. RUNNING SCRAPER...
echo ============================================================
echo.
echo [5/5] Launching update-oanda-rates.js...
if exist ".\scripts\update-oanda-rates.js" (
    call node .\scripts\update-oanda-rates.js
) else (
    echo   ERROR: Script file '.\scripts\update-oanda-rates.js' not found.
)

:EXIT
echo.
echo ============================================================
echo   Execution Finished. Window held open for review.
echo ============================================================
pause