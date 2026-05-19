import sys
import pandas as pd
from simple_salesforce import Salesforce
import os
from datetime import datetime
from dotenv import load_dotenv

# --- 1. LOAD CREDENTIALS ---
env_path = r'C:\Creds\cd.env'
load_dotenv(dotenv_path=env_path)

USERNAME = os.getenv('SF_USERNAME')
PASSWORD = os.getenv('SF_PASSWORD')
TOKEN = os.getenv('SF_TOKEN')
CONSUMER_KEY = os.getenv('SF_CONSUMER_KEY')
CONSUMER_SECRET = os.getenv('SF_CONSUMER_SECRET')

# --- 2. FILE PATHS ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MASTER_FILE = os.path.join(BASE_DIR, 'TE access and activities - currencyUpdate - TE access and activities - currencyUpdate.csv')
LOG_FILE = os.path.join(BASE_DIR, 'log.txt')

# Define target API version centrally
SF_VERSION = '64.0'

def write_log(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"[{timestamp}] {message}\n")
    print(message)

def run_sync():
    # --- TIME WINDOW CHECK (10 AM to 5 PM IST) ---
    now = datetime.now()
    current_hour = now.hour
    
    # 10 is 10 AM, 17 is 5 PM. Logic: Proceed only if hour is >= 10 AND < 17
    if not (10 <= current_hour < 20):
        print(f"Skipping sync: Current time ({now.strftime('%I:%M %p')}) is outside allowed window (10 AM - 5 PM IST).")
        return

    write_log(f"--- Starting Salesforce Composite Sync (API v{SF_VERSION}) ---")

    # --- STEP 0: CONNECT VIA OAUTH ---
    try:
        sf = Salesforce(
            domain='login', 
            username=USERNAME, 
            password=PASSWORD, 
            security_token=TOKEN,
            consumer_key=CONSUMER_KEY,
            consumer_secret=CONSUMER_SECRET,
            version=SF_VERSION
        )
        write_log("Connected to Salesforce successfully via OAuth.")
    except Exception as e:
        write_log(f"CRITICAL ERROR: Connection Failed: {e}")
        return

    # --- STEP 1: CHECK FOR EXISTING RECORDS FOR TODAY ---
    try:
        today_str = datetime.now().strftime('%Y-%m-%d')
        query = f"SELECT Id, CreatedBy.Name, CreatedDate FROM DatedConversionRate WHERE StartDate = {today_str}"
        result = sf.query(query)

        if result['totalSize'] > 0:
            first_record = result['records'][0]
            creator_name = first_record['CreatedBy']['Name']
            
            utc_time = pd.to_datetime(first_record['CreatedDate'])
            ist_time = utc_time.tz_convert('Asia/Kolkata').strftime('%I:%M %p')
            
            confirm = input(f"\nLooks like currency update already done by {creator_name} at {ist_time} IST for today, would you still like to continue? (yes/no): ").strip().lower()
            
            if confirm == 'yes':
                write_log(f"User chose to overwrite. Deleting {result['totalSize']} existing records from {ist_time}...")
                ids_to_delete = [{'Id': r['Id']} for r in result['records']]
                sf.bulk.DatedConversionRate.delete(ids_to_delete)
                write_log("Existing records deleted. Proceeding with fresh sync...")
            else:
                write_log(f"User cancelled sync: Records already exist for today (Created by {creator_name} at {ist_time} IST).")
                input("\nPress Enter to close...")
                return
        else:
            write_log(f"No records found for {today_str}. Proceeding automatically...")

    except Exception as e:
        write_log(f"WARNING: Could not check/clean existing records: {e}")
        confirm = input("Proceed anyway? (yes/no): ").strip().lower()
        if confirm != 'yes': return

    # --- STEP 2: PROCESS FILE & PREPARE BATCHES ---
    try:
        if not os.path.exists(MASTER_FILE):
            write_log(f"FILE ERROR: {MASTER_FILE} not found.")
            return

        df = pd.read_csv(MASTER_FILE, encoding='unicode_escape')
        
        composite_requests = []
        dated_inserts = []

        for _, row in df.iterrows():
            if 'Id' in row and pd.notnull(row['Id']):
                composite_requests.append({
                    "method": "PATCH",
                    "url": f"/services/data/v{SF_VERSION}/sobjects/CurrencyType/{row['Id']}",
                    "referenceId": f"ref_{row['Id']}",
                    "body": {"ConversionRate": float(row['ConversionRate'])}
                })
            
            clean_date = pd.to_datetime(row['StartDate'], errors='coerce').strftime('%Y-%m-%d')
            dated_inserts.append({
                'IsoCode': row['ISOCODE'], 
                'ConversionRate': float(row['ConversionRate']),
                'StartDate': clean_date
            })

        # --- STEP 3: EXECUTE COMPOSITE UPDATE ---
        if composite_requests:
            write_log(f"Sending {len(composite_requests)} updates via Composite API...")
            data = {"allOrNone": True, "compositeRequest": composite_requests}
            url = f"https://{sf.sf_instance}/services/data/v{SF_VERSION}/composite"
            response_raw = sf.session.post(url, json=data, headers=sf.headers)
            
            if response_raw.status_code == 200:
                response = response_raw.json()
                has_error = False
                for sub_res in response.get('compositeResponse', []):
                    if sub_res['httpStatusCode'] >= 400:
                        write_log(f"ERROR on {sub_res['referenceId']}: {sub_res['body']}")
                        has_error = True
                if not has_error:
                    write_log("SUCCESS: All CurrencyType updates completed.")
            else:
                write_log(f"COMPOSITE HTTP ERROR: {response_raw.status_code} - {response_raw.text}")

        # --- STEP 4: BULK INSERT ---
        if dated_inserts:
            write_log(f"Sending {len(dated_inserts)} DatedConversionRate inserts...")
            results = sf.bulk.DatedConversionRate.insert(dated_inserts)
            for i, res in enumerate(results):
                if res['success']:
                    write_log(f"SUCCESS: Inserted {dated_inserts[i]['IsoCode']}")
                else:
                    write_log(f"ERROR: {dated_inserts[i]['IsoCode']} - {res['errors']}")

    except Exception as e:
        write_log(f"CRITICAL ERROR: {e}")

    write_log("--- Sync Finished ---\n")
    input("Press Enter to exit.")

if __name__ == "__main__":
    run_sync()