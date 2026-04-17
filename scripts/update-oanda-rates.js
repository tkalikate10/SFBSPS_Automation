const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require('playwright');

const DEFAULT_OUTPUT = path.join(
  __dirname,
  '..',
  'BSPS AUtoamtion',
  'TE access and activities - currencyUpdate - TE access and activities - currencyUpdate.csv'
);

function parseArgs(argv) {
  const args = {
    output: DEFAULT_OUTPUT,
    headless: true,
    timeoutMs: 30000
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--output' && argv[index + 1]) {
      args.output = path.resolve(argv[index + 1]);
      index += 1;
    } else if (arg === '--headed') {
      args.headless = false;
    } else if (arg === '--timeout' && argv[index + 1]) {
      args.timeoutMs = Number(argv[index + 1]);
      index += 1;
    }
  }

  return args;
}

function formatStartDate(date) {
  return `${date.getMonth() + 1}/${date.getDate()}/${date.getFullYear()}`;
}

function csvEscape(value) {
  const text = String(value ?? '');
  if (text.includes(',') || text.includes('"') || text.includes('\n')) {
    return `"${text.replace(/"/g, '""')}"`;
  }
  return text;
}

function parseCsv(content) {
  const lines = content.trim().split(/\r?\n/);
  const header = lines[0].split(',');
  const rows = [];
  for (let i = 1; i < lines.length; i += 1) {
    const values = lines[i].split(',');
    const row = {};
    for (let j = 0; j < header.length; j += 1) {
      row[header[j]] = values[j] ?? '';
    }
    rows.push(row);
  }
  return { header, rows };
}

async function extractRate(page) {
  await page.waitForFunction(
    () => {
      const filledInputs = Array.from(document.querySelectorAll('input.MuiFilledInput-input'));
      return filledInputs.length >= 2 && filledInputs[1].value && filledInputs[1].value !== '-';
    },
    { timeout: 30000 }
  );

  return page.evaluate(() => {
    const filledInputs = Array.from(document.querySelectorAll('input.MuiFilledInput-input'));
    return filledInputs[1].value;
  });
}

async function dismissCookieBanner(page) {
  const candidates = [
    'button:has-text("Accept")',
    'button:has-text("Allow all")',
    'button:has-text("I agree")'
  ];

  for (const selector of candidates) {
    const button = page.locator(selector).first();
    if (await button.count()) {
      try {
        await button.click({ timeout: 2000 });
        return;
      } catch {
        // Ignore non-clickable variants.
      }
    }
  }
}

async function scrapeCurrency(page, baseCurrency, timeoutMs) {
  // Now baseCurrency is the non-USD currency, quote is always USD
  const url = `https://www.oanda.com/currency-converter/en/?from=${baseCurrency}&to=USD&amount=1`;
  let lastError;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      await page.goto(url, { waitUntil: 'commit', timeout: timeoutMs });
      await dismissCookieBanner(page);
      const rate = await extractRate(page);
      return { rate };
    } catch (error) {
      lastError = error;
      await page.waitForTimeout(1500 * attempt);
    }
  }

  throw new Error(`Failed to scrape ${baseCurrency}: ${lastError.message}`);
}

async function writeCsv(outputPath, header, rows) {
  const lines = [header.join(',')];
  for (const row of rows) {
    lines.push(header.map((col) => csvEscape(row[col])).join(','));
  }

  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, `${lines.join('\n')}\n`, 'utf8');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  // Read existing CSV — currencies and static columns come from the file
  const content = await fs.readFile(args.output, 'utf8');
  const { header, rows } = parseCsv(content);

  if (rows.length === 0) {
    console.error('No data rows found in the CSV file.');
    process.exitCode = 1;
    return;
  }

  const today = formatStartDate(new Date());
  const browser = await chromium.launch({ headless: args.headless });
  const context = await browser.newContext();
  const page = await context.newPage();
  page.setDefaultTimeout(args.timeoutMs);

  try {
    for (const row of rows) {
      const isoCode = row.ISOCODE;
      const result = await scrapeCurrency(page, isoCode, args.timeoutMs);
      row.ConversionRate = result.rate;
      row.StartDate = today;
      console.log(`${isoCode}→USD: ${result.rate}`);
    }
  } finally {
    await browser.close();
  }

  await writeCsv(args.output, header, rows);
  console.log(`Updated ${rows.length} rows in ${args.output}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});