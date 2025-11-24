#!/bin/bash
set -euo pipefail

echo "Building DuckDB database from USCG NRC data..."

rm -f data/data.duckdb

duckdb data/data.duckdb << 'EOF'
install spatial;
load spatial;

-- Load sheets from Excel file
create or replace table calls as
select * from st_read('data/CY25.xlsx', layer='CALLS', open_options=['HEADERS=FORCE']);

create or replace table incident_commons as
select * from st_read('data/CY25.xlsx', layer='INCIDENT_COMMONS', open_options=['HEADERS=FORCE']);

create or replace table materials as
select * from st_read('data/CY25.xlsx', layer='MATERIAL_INVOLVED', open_options=['HEADERS=FORCE']);

create or replace table incident_details as
select * from st_read('data/CY25.xlsx', layer='INCIDENT_DETAILS', open_options=['HEADERS=FORCE']);

-- Get incidents from last 30 days
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
where c.DATE_TIME_RECEIVED::DATE >= current_date - interval 30 day
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

-- Light pre-filter: exclude obvious noise, let Claude do the real filtering
create or replace table priority_incidents as
select
    SEQNOS,
    DATE_TIME_RECEIVED,
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
order by priority_score, DATE_TIME_RECEIVED desc;

-- Summary stats
create or replace table summary_stats as
select
    count(*) as total_recent_incidents,
    count(distinct RESPONSIBLE_COMPANY) filter (where RESPONSIBLE_COMPANY is not null) as unique_companies,
    sum(case when any_injuries = 'Y' then 1 else 0 end) as incidents_with_injuries,
    sum(case when any_fatalities = 'Y' then 1 else 0 end) as incidents_with_fatalities,
    sum(case when any_evacuations = 'Y' then 1 else 0 end) as incidents_with_evacuations,
    sum(case when waterway_closed = 'Y' then 1 else 0 end) as waterway_closures,
    min(DATE_TIME_RECEIVED) as earliest_date,
    max(DATE_TIME_RECEIVED) as latest_date
from enriched_incidents;

-- Drop intermediate tables
drop table calls;
drop table incident_commons;
drop table materials;
drop table incident_details;
drop table recent_calls;

-- Show counts
select 'enriched_incidents' as table_name, count(*) as row_count from enriched_incidents
union all
select 'priority_incidents', count(*) from priority_incidents;
EOF

# Remove raw Excel file
rm -f data/CY25.xlsx

echo "Database built successfully!"
