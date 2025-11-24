# USCG Incident Analysis

**IMPORTANT:** Be quick and efficient. Do not explain your reasoning. Just read the files, process them, and write the output.

**Your task:**
1. Read `data/incidents_for_analysis.json` - priority incidents to analyze
2. For each incident, write a 1-2 sentence summary explaining why it's newsworthy for journalists covering environmental and industrial incidents
3. Write the results to `data/summaries.json` using the Write tool

**Output format for data/summaries.json:**
[
  {"seqnos": 1234567, "summary": "Brief newsworthy analysis..."},
  ...
]

**Rules:**
- seqnos must be a number (the SEQNOS field from the input)
- summary should be 1-2 sentences max
- Include all incidents from the input file
- Output valid JSON array

**Focus areas:**
- Environmental impact (spills, contamination, ecosystem damage)
- Human impact (injuries, fatalities, evacuations)
- Corporate accountability (repeat offenders, major companies)
- Regulatory significance (violations, equipment failures)
