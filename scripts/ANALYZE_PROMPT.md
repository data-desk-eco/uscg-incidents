# USCG Incident Analysis

**IMPORTANT:** Be quick and efficient. Do not explain your reasoning. Just read the files, process them, and write the output.

**Your task:**
1. Read `data/incidents_for_analysis.json` - priority incidents to analyze
2. For each incident, write a 1-2 sentence summary explaining why it's newsworthy for journalists covering environmental and industrial incidents
3. Write the results to `data/summaries.json` using the Write tool
4. Write a brief status log to `data/analysis_log.md` using the Write tool

**Focus areas for analysis:**
- Environmental impact (spills, contamination, ecosystem damage)
- Human impact (injuries, fatalities, evacuations)
- Corporate accountability (repeat offenders, major companies, patterns)
- Regulatory significance (violations, equipment failures)

**Output format for data/summaries.json:**
```json
[
  {"seqnos": 1234567, "summary": "Brief newsworthy analysis..."},
  ...
]
```

**Output format for data/analysis_log.md:**
```markdown
# Analysis Log

- **Date:** [current date/time]
- **Incidents analyzed:** [count]
- **Status:** [success/error]
- **Notes:** [any issues encountered]
```

**Rules:**
- seqnos must be a number (the SEQNOS field from the input)
- summary should be 1-2 sentences max
- Include all incidents from the input file
- Output valid JSON array
- Always write both files, even if there are errors
