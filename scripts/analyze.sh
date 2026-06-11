#!/bin/bash
set -euo pipefail

echo "Analyzing priority incidents with Claude..."

# Export incidents not yet reviewed by Claude (use CSV quoting to handle multiline descriptions)
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
    from incidents
    where not reviewed
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

# Store summaries, mark everything exported as reviewed, persist the archive
echo "Updating database with $(jq length data/summaries.json) summaries..."
duckdb data/data.duckdb << 'EOF'
UPDATE incidents SET claude_summary = j.summary
FROM read_json('data/summaries.json', columns={seqnos: 'bigint', summary: 'varchar'}) j
WHERE incidents.SEQNOS = j.seqnos;

UPDATE incidents SET reviewed = true
WHERE SEQNOS IN (SELECT SEQNOS FROM read_csv('data/incidents_for_analysis.csv'));

COPY (SELECT * FROM incidents ORDER BY incident_date DESC, SEQNOS) TO 'data/incidents.csv' (HEADER);
EOF
echo "Database updated with Claude summaries"

# Cleanup temporary files
rm -f data/incidents_for_analysis.csv data/summaries.json

echo "Analysis complete!"
