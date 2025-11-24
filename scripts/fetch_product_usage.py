# scripts/fetch_product_usage.py
# Fetch product usage from API for a date range and write NDJSON to Azure Blob.
# Usage:
#   python fetch_product_usage.py --start 2025-11-23 --end 2025-11-23
#   python fetch_product_usage.py --start 2025-11-23 --end 2025-11-23 --mock

import os
import argparse
import json
import time
from datetime import datetime, timedelta

# pip: azure-storage-blob, requests, python-dotenv
try:
    import requests
    from azure.storage.blob import BlobServiceClient
    from dotenv import load_dotenv
except Exception:
    pass  # in case dependencies aren't installed; user will install

# load local .env if present
load_dotenv = None
try:
    from dotenv import load_dotenv as _load
    _load()
except Exception:
    pass

API_URL = os.environ.get("API_URL", "http://localhost:4000/usage")
API_KEY = os.environ.get("API_KEY", "")
BLOB_CONN_STR = os.environ.get("BLOB_CONN_STR", "")
BLOB_CONTAINER = os.environ.get("BLOB_CONTAINER", "product-api-raw")

def fetch_page(date_str, page=1, per_page=1000):
    """Call product API for a single page."""
    headers = {"Accept": "application/json"}
    if API_KEY:
        headers["Authorization"] = f"Bearer {API_KEY}"
    params = {"date": date_str, "page": page, "per_page": per_page}
    resp = requests.get(API_URL, params=params, headers=headers, timeout=30)
    resp.raise_for_status()
    return resp.json()

def fetch_day_to_blob(date_obj, mock=False):
    """Fetch all pages for a date and write NDJSON to blob."""
    date_str = date_obj.strftime("%Y-%m-%d")
    lines = []
    if mock:
        # read sample file from repo
        sample_path = os.path.join(os.path.dirname(__file__), "..", "samples", "product_api_sample.json")
        with open(sample_path, "r") as f:
            data = json.load(f)
        items = data.get("items", [])
        for it in items:
            rec = {
                "company_id": it.get("company_id"),
                "date": date_str,
                "active_users": int(it.get("active_users") or 0),
                "events": int(it.get("events") or 0),
                "raw_ts": it.get("ts")
            }
            lines.append(json.dumps(rec))
    else:
        page = 1
        while True:
            payload = fetch_page(date_str, page=page)
            items = payload.get("items", [])
            for it in items:
                rec = {
                    "company_id": it.get("company_id"),
                    "date": date_str,
                    "active_users": int(it.get("active_users") or 0),
                    "events": int(it.get("events") or 0),
                    "raw_ts": it.get("ts")
                }
                lines.append(json.dumps(rec))
            if not payload.get("next_page"):
                break
            page += 1
            time.sleep(0.1)

    # write to blob
    if not BLOB_CONN_STR:
        # write to local samples_output if blob not configured
        out_dir = os.path.join(os.path.dirname(__file__), "..", "samples_output")
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, f"usage_{date_str}.ndjson")
        with open(out_path, "w") as f:
            f.write("\n".join(lines))
        print(f"Wrote {len(lines)} lines to {out_path}")
        return out_path

    blob_svc = BlobServiceClient.from_connection_string(BLOB_CONN_STR)
    cont = blob_svc.get_container_client(BLOB_CONTAINER)
    blob_name = f"date={date_str}/usage_{date_str}_{int(time.time())}.ndjson"
    cont.get_blob_client(blob_name).upload_blob("\n".join(lines), overwrite=True)
    print(f"Wrote {len(lines)} records to blob://{BLOB_CONTAINER}/{blob_name}")
    return blob_name

def fetch_range(start_date_str, end_date_str, mock=False):
    start = datetime.strptime(start_date_str, "%Y-%m-%d").date()
    end = datetime.strptime(end_date_str, "%Y-%m-%d").date()
    cur = start
    while cur <= end:
        fetch_day_to_blob(cur, mock=mock)
        cur += timedelta(days=1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", required=True)
    parser.add_argument("--end", required=True)
    parser.add_argument("--mock", action="store_true", help="use local sample JSON instead of calling API")
    args = parser.parse_args()
    fetch_range(args.start, args.end, mock=args.mock)
