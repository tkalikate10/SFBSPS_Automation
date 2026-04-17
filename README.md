# BSPS Currency Rate Automation

This project scrapes daily exchange rates from OANDA and updates the BSPS currency CSV on a daily schedule. It is built to run without Visual Studio and can be installed and executed from the command line on a new Windows machine.

## What it does

- Reads the existing CSV file in `BSPS AUtoamtion`
- Uses the `ISOCODE` value from each row as the base currency
- Scrapes OANDA for the rate against USD
- Updates only these columns on each run:
  - `StartDate`
  - `ConversionRate`
- Preserves these columns exactly as-is:
  - `Id`
  - `ISOCODE`
  - `source_url`

## Source files to push to git

Push these files to the repository:

- `.gitignore`
- `README.md`
- `package.json`
- `scripts/update-oanda-rates.js`
- `scripts/run-oanda-update.ps1`
- `scripts/register-oanda-task.ps1`

Do not push these generated or local-only files:

- `node_modules/`
- `logs/`
- `BSPS AUtoamtion/*.csv`

## Project structure

- `scripts/update-oanda-rates.js` - Playwright scraper that reads the existing CSV and updates only `ConversionRate` and `StartDate`
- `scripts/run-oanda-update.ps1` - PowerShell wrapper that runs the scraper and writes logs
- `scripts/register-oanda-task.ps1` - One-time scheduled task registration script
- `BSPS AUtoamtion/TE access and activities - currencyUpdate - TE access and activities - currencyUpdate.csv` - working CSV input/output file

## Prerequisites

You do not need Visual Studio.

Install these items on the machine:

- Node.js LTS
- Git
- PowerShell 5.1 or PowerShell 7

### Install Node.js from CLI

If the machine has `winget`, install Node.js LTS from PowerShell:

```powershell
winget install -e --id OpenJS.NodeJS.LTS
```

Verify the install:

```powershell
node -v
npm -v
```

If `winget` is not available, download and install Node.js LTS from https://nodejs.org.

## First-time setup on a new machine

### 1. Install Node.js

Use the CLI command above if `winget` is available, or install Node.js LTS from https://nodejs.org.

### 2. Clone the repository

```powershell
git clone <repo-url> C:\log-analysis-agent
cd C:\log-analysis-agent
```

### 3. Install dependencies

```powershell
npm install --registry=https://registry.npmjs.org/
```

### 4. Install the Playwright browser

```powershell
npx playwright install chromium
```

### 5. Run the scraper once manually

```powershell
node .\scripts\update-oanda-rates.js
```

This reads the CSV in `BSPS AUtoamtion`, scrapes OANDA, and updates only the rate column and the start date.

## Daily refresh using Task Scheduler

Register the scheduled task one time:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\register-oanda-task.ps1 -StartTime "08:00"
```

That creates a daily task named `Daily OANDA Currency Refresh`.

To verify the task:

```powershell
schtasks /Query /TN "Daily OANDA Currency Refresh" /FO LIST
```

## How the automation works

1. The PowerShell wrapper starts the scraper.
2. The scraper reads the existing CSV rows.
3. For each row, it uses `ISOCODE` to build the OANDA URL.
4. It scrapes the current rate for `<currency> -> USD`.
5. It updates only `ConversionRate` and `StartDate`.
6. It writes the CSV back in the same format.

## Run manually anytime

```powershell
node .\scripts\update-oanda-rates.js
```

Optional flags:

```powershell
node .\scripts\update-oanda-rates.js --headed
node .\scripts\update-oanda-rates.js --timeout 60000
node .\scripts\update-oanda-rates.js --output "C:\path\to\file.csv"
```

## Logs

Each scheduled run writes a log file in the `logs` folder.

If the run fails, check the latest log file first.

## Notes for team members without Visual Studio

This setup is CLI-based.

A new machine only needs:

- Node.js
- Git
- the repository
- `npm install`
- `npx playwright install chromium`

After that, they can run the automation from PowerShell or let Task Scheduler run it daily.
