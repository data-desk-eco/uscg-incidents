#!/bin/bash
set -euo pipefail

echo "Analyzing priority incidents with Claude..."

# Export all incidents for analysis (use JSON to handle multiline descriptions)
duckdb data/data.duckdb -c "
COPY (
    select
        SEQNOS,
        incident_date,
        referenced_seqnos,
        RESPONSIBLE_COMPANY,
        incident_city,
        incident_state,
        replace(description, E'\n', ' ') as description,
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
    order by incident_date desc
) TO 'data/incidents_for_analysis.csv' (HEADER, DELIMITER ',');
"

# Get count (subtract 1 for header row)
count=$(($(wc -l < data/incidents_for_analysis.csv) - 1))
echo "Found $count incidents to analyze"

# Skip if no incidents
if [ "$count" -le 0 ]; then
    echo "No incidents to analyze, skipping"
    rm -f data/incidents_for_analysis.csv
    exit 0
fi

# Run Claude analysis - outputs directly to data/summaries.json via Write tool
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

# Cleanup temporary files
rm -f data/incidents_for_analysis.csv data/summaries.json

echo "Analysis complete!"
