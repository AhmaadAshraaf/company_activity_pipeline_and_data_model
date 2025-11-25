# Q2.3 — Example Pipeline Performance Issue & How I Debugged It

I’ll describe a real issue I faced while working on the GHC project at Google, where we ingested raw data from Google Sheets and Google Forms into GCP (BigQuery + Cloud Functions). The pipeline slowed down significantly and sometimes failed during peak data-collection periods.

### The Issue
The daily load began taking much longer than expected. A process that normally finished in a few minutes started taking **40–50 minutes**, and occasionally timed out. After investigation, three underlying problems surfaced:

1. **Google Sheets API rate limiting**  
   Several Sheets were being read repeatedly, row-by-row, instead of in batches. When data volume spiked (thousands of responses in a short window), the API throttled requests, causing retries and exponential backoff delays.

2. **Unbounded full reload**  
   The ingestion job pulled the *entire* sheet every time (all historical rows), even though only new responses were needed. As the sheet grew, the pipeline scanned more data every day.

3. **Data quality drift / schema inconsistencies**  
   Some Google Forms questions were edited mid-survey, which changed column order and introduced mixed data types. The ingestion job spent extra time normalizing rows and sometimes triggered BigQuery load failures that forced retries.

---

### How I Debugged It (step-by-step)

1. **Checked Cloud Functions logs**  
   I inspected cold-start times, retry patterns, and API error codes. Seeing repeated `429: Rate Limit Exceeded` errors confirmed throttling.

2. **Added lightweight instrumentation**  
   Logged row counts, processing time per sheet, and retry counts. This immediately showed which sheets had grown large enough to cause slowdowns.

3. **Pulled execution traces in Cloud Trace**  
   This revealed where latency accumulated — mostly in repeated API calls rather than BigQuery insertion.

4. **Ran targeted BigQuery profiling**  
   Checked whether downstream tables were scanning large partitions unnecessarily or encountering typecast errors. Found that schema drift required more fallback logic than expected.

5. **Tested incremental pull logic locally**  
   Added a simple “max timestamp seen” watermark and validated that only new rows needed to be inserted.

---

### The Fixes I Applied

- **Implemented incremental ingestion:**  
  Tracked the last processed timestamp and fetched only new Google Forms/Sheets rows. This cut API calls by ~90%.

- **Batch-read Google Sheets instead of row-by-row:**  
  Used `spreadsheets.values.batchGet` to pull ranges efficiently, reducing API throttling.

- **Introduced light schema validation & auto-normalization:**  
  Cast fields, aligned columns, and added a fallback mapping layer so form edits no longer broke the pipeline.

- **Added monitoring dashboards:**  
  Cloud Monitoring alerts for:
  - sheet API error spikes  
  - ingestion duration > N minutes  
  - schema mismatches  

After these changes the pipeline stabilized and ran consistently within a few minutes, even during peak data-submission periods.

---

### Why this example matters
It demonstrates:
- How performance issues often come from *upstream behavior* (API throttling, unbounded scans), not only infrastructure.
- How incremental design and batching dramatically improve pipeline speed.
- The value of structured debugging: logs → metrics → traces → schema checks.
