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

# Run Claude analysis - outputs directly to data/summaries.json via Write tool
echo "Running Claude analysis..."
if claude -p scripts/ANALYZE_PROMPT.md --print --output-format json --dangerously-skip-permissions > /dev/null 2>&1; then
    echo "Claude analysis complete"
else
    echo "Claude analysis failed, skipping summary update"
    rm -f data/incidents_for_analysis.json
    exit 0
fi

# Validate JSON output
if [ ! -f data/summaries.json ] || ! jq -e '.' data/summaries.json > /dev/null 2>&1; then
    echo "Invalid or missing JSON from Claude, skipping summary update"
    rm -f data/incidents_for_analysis.json data/summaries.json
    exit 0
fi

# Update database with summaries
summary_count=$(jq length data/summaries.json)
if [ "$summary_count" -gt 0 ]; then
    echo "Updating database with $summary_count summaries..."
    duckdb data/data.duckdb << 'EOF'
create or replace table claude_summaries as
select
    cast(seqnos as varchar) as incident_seqnos,
    summary
from read_json('data/summaries.json');

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
rm -f data/incidents_for_analysis.json data/summaries.json

echo "Analysis complete!"
