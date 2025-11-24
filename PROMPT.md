# USCG Incident Analysis

**IMPORTANT:** Be quick and efficient. Do not explain your reasoning. Just read the file, filter to newsworthy incidents, and write the output.

**Your task:**
1. Read `data/incidents_for_analysis.csv` — USCG National Response Center incidents from the last 30 days
2. **Filter** to only the incidents that would be newsworthy for journalists covering environmental and industrial incidents
3. For each newsworthy incident, write a 1-2 sentence summary explaining why it matters
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

**Output format for data/summaries.json:**
```json
[
  {"seqnos": 1234567, "summary": "Brief newsworthy analysis..."},
  ...
]
```

**Rules:**
- seqnos must be a number (the SEQNOS field from the CSV)
- summary should be 1-2 sentences max
- Only include incidents worth reporting — quality over quantity
- Output valid JSON array
