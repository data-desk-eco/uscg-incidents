# USCG Incident Analysis

**Be quick — complete this task in under 3 minutes.**

**Your task:**
1. Read `data/incidents_for_analysis.csv` — USCG National Response Center incidents from the last 30 days
2. **Filter** to only the incidents that would be newsworthy for journalists covering environmental and industrial incidents
3. For each newsworthy incident, write a short summary in plain English (1-2 sentences)
4. Write results to `data/summaries.json` using the Write tool

**What makes an incident newsworthy:**
- Significant environmental impact (large spills, toxic materials, ecosystem damage)
- Human impact (injuries, fatalities, evacuations)
- Major companies or repeat offenders
- Regulatory failures, equipment failures, negligence
- Unusual or notable circumstances

**What to skip:**
- Minor spills with no injuries or environmental concern
- Routine reports with minimal impact
- Incidents with minimal details that don't tell a story

**CRITICAL — Write each summary yourself:**
- Do NOT write code to generate summaries. Write each one by hand.
- Do NOT use string templates or interpolation.
- Do NOT copy-paste the raw description field — it's in ALL CAPS and reads like a police report.
- Rewrite the information in your own words, as a journalist would.

**Writing style:**
- Write like a news brief: clear, concise, human-readable
- Synthesize the details into a coherent narrative
- Use proper capitalization and grammar
- Example: "A tanker truck overturned on Highway 10 near Lordsburg, NM, killing the driver and spilling 7,500 gallons of diesel onto the roadway."

**Output format:**
Write `data/summaries.json` as a JSON array. Write the entire file content directly — do not use code to construct it.

```json
[
  {"seqnos": 1234567, "summary": "Your written summary here."},
  {"seqnos": 1234568, "summary": "Another written summary."}
]
```

**Rules:**
- seqnos: the SEQNOS number from the CSV
- summary: 1-2 sentences, written by you, not generated
- Only include genuinely newsworthy incidents
- Valid JSON array (no trailing commas)
