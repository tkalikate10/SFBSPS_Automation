import sys
import pandas as pd
from simple_salesforce import Salesforce
import os
from datetime import datetime

# --- 1. CREDENTIALS ---
USERNAME = XXXXXXXX
PASSWORD = XXXXXXXXXXX
TOKEN = XXXXXXXXXXX

# --- 2. FILE PATHS ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MASTER_FILE = os.path.join(BASE_DIR, 'TE access and activities - currencyUpdate - TE access and activities - currencyUpdate.csv')
LOG_FILE = os.path.join(BASE_DIR, 'log.txt')

def write_log(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"[{timestamp}] {message}\n")
    print(message)

def run_sync():
    write_log("--- Starting Dual Sync (Update & Insert) ---")

    # --- STEP 1: CONNECT TO SALESFORCE ---
    try:
        sf = Salesforce(domain='test', username=USERNAME, password=PASSWORD, security_token=TOKEN)
        write_log("Connected to Salesforce successfully.")
    except Exception as e:
        write_log(f"CRITICAL ERROR: Connection Failed: {e}")
        input("\nPress Enter to close...") # Keeps window open on error
        return

    # --- STEP 2: PROCESS FILE ---
    try:
        if not os.path.exists(MASTER_FILE):
            write_log(f"FILE ERROR: {MASTER_FILE} not found.")
            input("\nPress Enter to close...")
            return

        df = pd.read_csv(MASTER_FILE, encoding='unicode_escape')
        
        # PROMPT LOGIC (Must be indented inside the 'try' block)
        confirm = input(f"File loaded with {len(df)} rows. Proceed with Sync? (yes/no): ").strip().lower()
        if confirm != 'yes':
            write_log("User cancelled the sync.")
            input("\nPress Enter to close...")
            return

        for _, row in df.iterrows():
            # --- OPERATION 1: UPDATE ---
            try:
                if 'Id' in row and pd.notnull(row['Id']):
                    sf.CurrencyType.update(row['Id'], {
                        'ConversionRate': float(row['ConversionRate'])
                    })
                    write_log(f"STEP 1 SUCCESS: Updated CurrencyType {row['Id']}")
                else:
                    write_log(f"STEP 1 SKIP: No Id found for row {row.get('ISOCODE')}")
            except Exception as e:
                write_log(f"STEP 1 ERROR: Updating Id {row.get('Id')}: {e}")

            # --- OPERATION 2: INSERT ---
            try:
                clean_date = pd.to_datetime(row['StartDate'], errors='coerce').strftime('%Y-%m-%d')
                sf.DatedConversionRate.create({
                    'IsoCode': row['ISOCODE'], 
                    'ConversionRate': float(row['ConversionRate']),
                    'StartDate': clean_date
                })
                write_log(f"STEP 2 SUCCESS: Inserted DatedRate {row['ISOCODE']} for {clean_date}")
            except Exception as e:
                write_log(f"STEP 2 ERROR: Inserting DatedRate {row.get('ISOCODE')}: {e}")

    except Exception as e:
        write_log(f"FILE ERROR: Processing failed: {e}")

    write_log("--- Dual Sync Finished ---\n")
    input("All tasks complete. Press Enter to exit.") # Keeps window open after success

if __name__ == "__main__":
    run_sync()
