# USCG Incident Analysis

**IMPORTANT:** Be quick and efficient. Do not explain your reasoning. Just read the file, filter to newsworthy incidents, and write the output.

**Your task:**
1. Read `data/incidents_for_analysis.csv` — USCG National Response Center incidents from the last 30 days
2. **Filter** to only the incidents that would be newsworthy for journalists covering environmental and industrial incidents
3. For each newsworthy incident, write a short description in plain English (up to 100 words)
4. Write results to `data/summaries.json` using the Write tool

**What makes an incident newsworthy:**
- Significant environmental impact (large spills, toxic materials, ecosystem damage)
- Human impact (injuries, fatalities, evacuations)
- Major companies or repeat offenders
- Regulatory failures, equipment failures, negligence
- Unusual or notable circumstances

**What to skip:**
- Minor spills with no injuries or environmental concern
- Routine reports with no significant impact
- Incidents with minimal details that don't tell a story

**Writing style:**
- Write like a journalist, not a database
- Describe what happened in plain English
- Do NOT just echo field names like "1 fatality(ies) in mobile incident" — write a real description
- Include key details: who, what, where, consequences

**Output format for data/summaries.json:**
```json
[
  {"seqnos": 1234567, "summary": "A tanker truck overturned on Highway 10 near Lordsburg, NM, killing the driver and spilling 7,500 gallons of diesel fuel onto the highway and surrounding soil."},
  ...
]
```

**Rules:**
- seqnos must be a number (the SEQNOS field from the CSV)
- summary: plain English description, up to 100 words
- Only include incidents worth reporting — quality over quantity
- Output valid JSON array
