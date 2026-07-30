#!/bin/bash
set -euo pipefail

echo "Building DuckDB database from USCG NRC data..."

# Build union queries from available xlsx files. nullglob makes the guard below
# work: without it an unmatched glob survives as a literal one-element array and
# the count is never zero, so a failed download reached st_read as a bad path.
shopt -s nullglob
XLSX_FILES=(data/CY*.xlsx)
if [ ${#XLSX_FILES[@]} -eq 0 ]; then
    echo "Error: No CY*.xlsx files found in data/"
    exit 1
fi

# Build SQL fragments for each table by unioning all available files
make_union() {
    local layer=$1
    local first=true
    for f in "${XLSX_FILES[@]}"; do
        if $first; then first=false; else echo "union all by name"; fi
        # NRC's export leaves unbalanced quotes in free-text description fields, so
        # some rows spill prose into SEQNOS and the column reads back as varchar.
        # try_cast nulls those strays (they never join) and keeps SEQNOS one type
        # across years, which a bare `select *` union does not guarantee.
        echo "select * replace (try_cast(SEQNOS as bigint) as SEQNOS) from st_read('$f', layer='$layer', open_options=['HEADERS=FORCE'])"
    done
}

# merge any previously archived incidents (committed as csv so the record persists across runs)
ARCHIVE_SQL=""
if [ -f data/incidents.csv ]; then
ARCHIVE_SQL="
update incidents set claude_summary = a.claude_summary, reviewed = a.reviewed
from read_csv('data/incidents.csv') a where incidents.SEQNOS = a.SEQNOS;
insert into incidents select * from read_csv('data/incidents.csv') a
where a.SEQNOS not in (select SEQNOS from incidents);"
fi

CALLS_SQL=$(make_union CALLS)
COMMONS_SQL=$(make_union INCIDENT_COMMONS)
MATERIALS_SQL=$(make_union MATERIAL_INVOLVED)
DETAILS_SQL=$(make_union INCIDENT_DETAILS)

# work in memory, publish only final tables to a fresh committed db
# -bail stops at the first error; without it one bad statement cascades into a
# wall of "table does not exist" that buries the actual cause
rm -f data/data.duckdb
duckdb -bail << EOF
install spatial;
load spatial;
attach 'data/data.duckdb' as db;

-- Load sheets from all available year files
create or replace table calls as
$CALLS_SQL;

create or replace table incident_commons as
$COMMONS_SQL;

create or replace table materials as
$MATERIALS_SQL;

create or replace table incident_details as
$DETAILS_SQL;

-- Get incidents from the last 3 months
create or replace table recent_calls as
select distinct
    c.SEQNOS,
    c.DATE_TIME_RECEIVED,
    c.DATE_TIME_COMPLETE,
    c.CALLTYPE,
    c.RESPONSIBLE_COMPANY,
    c.RESPONSIBLE_ORG_TYPE,
    c.RESPONSIBLE_CITY,
    c.RESPONSIBLE_STATE,
    c.SOURCE
from calls c
where c.DATE_TIME_RECEIVED::DATE >= current_date - interval 3 month
  and c.CALLTYPE = 'INC'
order by c.DATE_TIME_RECEIVED desc;

-- Enrich with incident details
create or replace table enriched_incidents as
select
    rc.SEQNOS,
    rc.DATE_TIME_RECEIVED,
    rc.RESPONSIBLE_COMPANY,
    rc.RESPONSIBLE_STATE,
    rc.SOURCE,
    max(ic.DESCRIPTION_OF_INCIDENT) as description,
    max(ic.TYPE_OF_INCIDENT) as incident_type,
    max(ic.INCIDENT_CAUSE) as incident_cause,
    max(ic.INCIDENT_LOCATION) as location,
    max(ic.LOCATION_NEAREST_CITY) as incident_city,
    max(ic.LOCATION_STATE) as incident_state,
    max(ic.LOCATION_COUNTY) as county,
    list(m.NAME_OF_MATERIAL order by m.NAME_OF_MATERIAL) filter (where m.SEQNOS is not null) as materials,
    list(m.AMOUNT_OF_MATERIAL order by m.NAME_OF_MATERIAL) filter (where m.SEQNOS is not null) as amounts,
    list(m.UNIT_OF_MEASURE order by m.NAME_OF_MATERIAL) filter (where m.SEQNOS is not null) as units,
    max(id.ANY_INJURIES) as any_injuries,
    max(id.NUMBER_INJURED) as number_injured,
    max(id.ANY_FATALITIES) as any_fatalities,
    max(id.NUMBER_FATALITIES) as number_fatalities,
    max(id.ANY_EVACUATIONS) as any_evacuations,
    max(id.NUMBER_EVACUATED) as number_evacuated,
    max(id.ANY_DAMAGES) as any_damages,
    max(id.DAMAGE_AMOUNT) as damage_amount,
    max(id.WATERWAY_CLOSED) as waterway_closed,
    max(id.MEDIA_INTEREST) as media_interest
from recent_calls rc
left join incident_commons ic on rc.SEQNOS = ic.SEQNOS
left join materials m on rc.SEQNOS = m.SEQNOS
left join incident_details id on rc.SEQNOS = id.SEQNOS
group by rc.SEQNOS, rc.DATE_TIME_RECEIVED, rc.RESPONSIBLE_COMPANY,
         rc.RESPONSIBLE_STATE, rc.SOURCE;

-- Add incident_date: resolve update references to find original incident date
alter table enriched_incidents add column incident_date date;
alter table enriched_incidents add column ref varchar;
update enriched_incidents set
    incident_date = DATE_TIME_RECEIVED,
    ref = regexp_extract(description, 'REPORT[S]?\s*(?:#|NUMBER)?\s*(\d{6,7})', 1);

-- Iteratively resolve chained updates (handles update -> update -> ... -> original)
update enriched_incidents as e set incident_date = o.incident_date
from enriched_incidents o where TRY_CAST(e.ref AS INT) = o.SEQNOS and o.incident_date < e.incident_date;
update enriched_incidents as e set incident_date = o.incident_date
from enriched_incidents o where TRY_CAST(e.ref AS INT) = o.SEQNOS and o.incident_date < e.incident_date;
update enriched_incidents as e set incident_date = o.incident_date
from enriched_incidents o where TRY_CAST(e.ref AS INT) = o.SEQNOS and o.incident_date < e.incident_date;
update enriched_incidents as e set incident_date = o.incident_date
from enriched_incidents o where TRY_CAST(e.ref AS INT) = o.SEQNOS and o.incident_date < e.incident_date;

-- Light pre-filter: exclude obvious noise, let Claude do the real filtering
create or replace table priority_incidents as
select
    SEQNOS,
    incident_date,
    ref as referenced_seqnos,
    RESPONSIBLE_COMPANY,
    incident_city,
    incident_state,
    description,
    incident_type,
    incident_cause,
    materials,
    amounts,
    units,
    any_injuries,
    number_injured,
    any_fatalities,
    number_fatalities,
    any_evacuations,
    number_evacuated,
    damage_amount,
    waterway_closed,
    media_interest,
    -- Priority score for sorting (puts high-impact first for Claude to see)
    case
        when media_interest = 'HIGH' then 1
        when any_fatalities = 'Y' then 2
        when any_evacuations = 'Y' then 3
        when waterway_closed = 'Y' then 4
        when any_injuries = 'Y' then 5
        when media_interest = 'MEDIUM' then 6
        else 7
    end as priority_score,
    null::varchar as claude_summary
from enriched_incidents
where incident_cause != 'TRESPASSER'
order by priority_score, incident_date desc;

-- Summary stats
create or replace table summary_stats as
select
    count(*) as total_recent_incidents,
    count(distinct RESPONSIBLE_COMPANY) filter (where RESPONSIBLE_COMPANY is not null) as unique_companies,
    sum(case when any_injuries = 'Y' then 1 else 0 end) as incidents_with_injuries,
    sum(case when any_fatalities = 'Y' then 1 else 0 end) as incidents_with_fatalities,
    sum(case when any_evacuations = 'Y' then 1 else 0 end) as incidents_with_evacuations,
    sum(case when waterway_closed = 'Y' then 1 else 0 end) as waterway_closures,
    min(incident_date) as earliest_date,
    max(incident_date) as latest_date
from enriched_incidents;

-- persistent archive: fresh window plus everything seen on previous runs
create or replace table incidents as
select * replace (materials::varchar as materials, amounts::varchar as amounts, units::varchar as units),
       false as reviewed
from priority_incidents;
$ARCHIVE_SQL
delete from incidents where incident_date < current_date - interval 3 month;
copy (select * from incidents order by incident_date desc, SEQNOS) to 'data/incidents.csv' (header);

-- Publish final tables
create table db.incidents as from incidents;
create table db.priority_incidents as from priority_incidents;
create table db.summary_stats as from summary_stats;

-- Show counts
select 'enriched_incidents' as table_name, count(*) as row_count from enriched_incidents
union all
select 'priority_incidents', count(*) from priority_incidents
union all
select 'incidents (archive)', count(*) from incidents;
EOF

# Remove raw Excel files
rm -f data/CY*.xlsx

echo "Database built successfully!"
