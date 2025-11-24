# scripts/load_samples_to_sql.py
# Load NDJSON files from samples_output/ (or local path) into stg.product_usage using pyodbc.
# Usage:
#   python load_samples_to_sql.py --source local --path samples_output
#   python load_samples_to_sql.py --source blob --container product-api-raw --date 2025-11-23

import os
import json
import argparse
from datetime import datetime
import pyodbc

SQL_CONN_STR = os.environ.get("SQL_CONN_STR", "")

def insert_rows(conn, rows):
    cursor = conn.cursor()
    for r in rows:
        cursor.execute("""
            INSERT INTO stg.product_usage (company_id, date, active_users, events, src_ingested_at, src_file_name, raw_json)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, r['company_id'], r['date'], r['active_users'], r['events'], datetime.utcnow(), r.get('src_file','local'), json.dumps(r))
    conn.commit()

def load_local(path):
    files = [f for f in os.listdir(path) if f.endswith(".ndjson")]
    conn = pyodbc.connect(SQL_CONN_STR)
    for f in files:
        rows = []
        with open(os.path.join(path, f), "r") as fh:
            for line in fh:
                rec = json.loads(line)
                rec['src_file'] = f
                rows.append(rec)
        if rows:
            insert_rows(conn, rows)
            print(f"Inserted {len(rows)} rows from {f}")
    conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", choices=["local"], default="local")
    parser.add_argument("--path", default="samples_output")
    args = parser.parse_args()
    if not SQL_CONN_STR:
        raise SystemExit("SQL_CONN_STR missing in env. Fill .env or set env var.")
    load_local(args.path)
