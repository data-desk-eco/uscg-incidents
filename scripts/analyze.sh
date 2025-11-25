#!/bin/bash
set -euo pipefail

echo "Analyzing priority incidents with Claude..."

# Get last analysis timestamp (default to epoch if file doesn't exist)
last_analysis="1970-01-01 00:00:00"
if [ -f data/last_analysis.txt ]; then
    last_analysis=$(cat data/last_analysis.txt)
fi
echo "Last analysis: $last_analysis"

# Export only incidents newer than last analysis
duckdb data/data.duckdb -csv -c "
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
    waterway_closed
from priority_incidents
where DATE_TIME_RECEIVED > '$last_analysis'::timestamp
order by DATE_TIME_RECEIVED desc
" > data/incidents_for_analysis.csv

# Get count (subtract 1 for header row)
count=$(($(wc -l < data/incidents_for_analysis.csv) - 1))
echo "Found $count new incidents since last analysis"

# Skip if no new incidents
if [ "$count" -le 0 ]; then
    echo "No new incidents to analyze, skipping"
    rm -f data/incidents_for_analysis.csv
    exit 0
fi

# Run Claude analysis - outputs directly to data/summaries.json via Write tool
# Match media repo pattern exactly
echo "Running Claude analysis..."
claude -p PROMPT.md --max-turns 30 --print --output-format json --dangerously-skip-permissions --setting-sources user > /dev/null 2>&1 || true
echo "Claude analysis complete"

# Validate JSON output
if [ ! -f data/summaries.json ] || ! jq -e '.' data/summaries.json > /dev/null 2>&1; then
    echo "Invalid or missing JSON from Claude, skipping summary update"
    rm -f data/incidents_for_analysis.csv data/summaries.json
    exit 0
fi

# Update database with summaries
summary_count=$(jq length data/summaries.json)
if [ "$summary_count" -gt 0 ]; then
    echo "Updating database with $summary_count summaries..."
    duckdb data/data.duckdb << 'EOF'
INSERT INTO claude_summaries SELECT cast(seqnos as varchar), summary FROM read_json('data/summaries.json')
ON CONFLICT (incident_seqnos) DO UPDATE SET summary = EXCLUDED.summary;

UPDATE priority_incidents SET claude_summary = cs.summary
FROM claude_summaries cs WHERE cast(priority_incidents.SEQNOS as varchar) = cs.incident_seqnos;
EOF
    echo "Database updated with Claude summaries"
else
    echo "No summaries to update"
fi

# Update last analysis timestamp
date -u '+%Y-%m-%d %H:%M:%S' > data/last_analysis.txt
echo "Updated last analysis timestamp"

# Cleanup temporary files
rm -f data/incidents_for_analysis.csv data/summaries.json

echo "Analysis complete!"
