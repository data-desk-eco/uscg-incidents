#!/bin/bash
set -euo pipefail

echo "Analyzing priority incidents with Claude..."

# Export priority incidents to JSON for Claude analysis
duckdb data/data.duckdb -json -c "
select
    SEQNOS,
    DATE_TIME_RECEIVED,
    RESPONSIBLE_COMPANY,
    incident_city,
    incident_state,
    description,
    incident_type,
    incident_cause,
    materials::varchar as materials,
    amounts::varchar as amounts,
    units::varchar as units,
    any_injuries,
    number_injured,
    any_fatalities,
    number_fatalities,
    any_evacuations,
    number_evacuated,
    damage_amount,
    waterway_closed,
    media_interest,
    priority_score
from priority_incidents
order by priority_score, DATE_TIME_RECEIVED desc
limit 50
" > data/incidents_for_analysis.json

# Get count
count=$(jq length data/incidents_for_analysis.json)
echo "Analyzing $count priority incidents..."

# Create prompt for Claude
cat > data/analysis_prompt.txt << 'PROMPT'
You are analyzing USCG National Response Center incident reports for investigative journalism leads.

For each incident below, provide a 1-2 sentence summary explaining why it's newsworthy or interesting for journalists covering the oil and gas industry. Focus on:
- Environmental impact (spills, contamination, ecosystem damage)
- Human impact (injuries, fatalities, evacuations)
- Corporate accountability (repeat offenders, major companies, patterns)
- Regulatory significance (violations, equipment failures)

Output valid JSON array with objects containing:
- seqnos: the incident ID (as a number)
- summary: your 1-2 sentence analysis

Only output the JSON array, no markdown code blocks, no other text.

INCIDENTS:
PROMPT

# Append incidents to prompt
cat data/incidents_for_analysis.json >> data/analysis_prompt.txt

# Run Claude analysis using Max plan
echo "Running Claude analysis..."
if claude -p "$(cat data/analysis_prompt.txt)" 2>/dev/null > data/claude_raw.txt; then
    echo "Claude analysis complete"
else
    echo "Claude analysis failed, creating empty summaries..."
    echo "[]" > data/summaries_clean.json
    rm -f data/incidents_for_analysis.json data/analysis_prompt.txt data/claude_raw.txt
    exit 0
fi

# Extract JSON from Claude's response (may be wrapped in code blocks)
# Try to extract JSON array from the response
if grep -q '^\[' data/claude_raw.txt; then
    # Plain JSON array
    cat data/claude_raw.txt > data/summaries_clean.json
elif grep -q '```json' data/claude_raw.txt; then
    # JSON in code block - extract it
    sed -n '/```json/,/```/p' data/claude_raw.txt | sed '1d;$d' > data/summaries_clean.json
elif grep -q '```' data/claude_raw.txt; then
    # Generic code block
    sed -n '/```/,/```/p' data/claude_raw.txt | sed '1d;$d' > data/summaries_clean.json
else
    # Try to find array in the output
    grep -o '\[.*\]' data/claude_raw.txt > data/summaries_clean.json 2>/dev/null || echo "[]" > data/summaries_clean.json
fi

# Validate JSON
if ! jq -e '.' data/summaries_clean.json > /dev/null 2>&1; then
    echo "Invalid JSON from Claude, skipping summary update"
    rm -f data/incidents_for_analysis.json data/analysis_prompt.txt data/claude_raw.txt data/summaries_clean.json
    exit 0
fi

# Update database with summaries
summary_count=$(jq length data/summaries_clean.json)
if [ "$summary_count" -gt 0 ]; then
    echo "Updating database with $summary_count summaries..."
    duckdb data/data.duckdb << 'EOF'
create or replace table claude_summaries as
select
    cast(seqnos as varchar) as incident_seqnos,
    summary
from read_json('data/summaries_clean.json');

update priority_incidents
set claude_summary = cs.summary
from claude_summaries cs
where cast(priority_incidents.SEQNOS as varchar) = cs.incident_seqnos;

drop table claude_summaries;
EOF
    echo "Database updated with Claude summaries"
else
    echo "No summaries to update"
fi

# Cleanup temporary files
rm -f data/incidents_for_analysis.json data/analysis_prompt.txt data/claude_raw.txt data/summaries_clean.json

echo "Analysis complete!"
