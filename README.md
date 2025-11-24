# USCG Incident Reports

Interactive notebook displaying priority incidents from the US Coast Guard National Response Center, analyzed for investigative journalism leads in the oil and gas industry.

## Data Source

**US Coast Guard National Response Center FOIA Files**
- URL: https://nrc.uscg.mil/
- Format: Multi-sheet Excel workbook (CY25.xlsx = Calendar Year 2025)
- Updates: Daily

The NRC receives reports of oil, chemical, radiological, biological, and etiological releases into the environment.

## Pipeline

1. **Download** - Fetches latest USCG NRC Excel data (~13MB)
2. **Process** - DuckDB extracts and joins incident tables, filters for priority incidents
3. **Analyze** - Claude CLI generates investigative journalism summaries for each incident
4. **Display** - Observable notebook renders interactive incident list

## Filtering Criteria

Priority incidents include:
- **Environmental releases**: Oil, crude, diesel, gasoline, natural gas, ammonia
- **Major companies**: Energy Transfer, Kinder Morgan, Phillips 66, Marathon, Chevron, etc.
- **Pipeline incidents**: All pipeline-related reports
- **High-impact events**: Injuries, fatalities, evacuations, waterway closures
- **Media interest**: Incidents flagged as high or medium media interest

## Usage

```bash
# Install dependencies
yarn

# Run full data pipeline (download, process, analyze)
make data

# Preview notebook locally
make preview

# Build for production
make build
```

## Structure

```
uscg-incidents/
├── docs/
│   ├── index.html           # Observable notebook (edit this)
│   └── .observable/dist/    # Built output (gitignored)
├── data/
│   └── data.duckdb          # Processed incident database
├── scripts/
│   ├── download.sh          # Download USCG data
│   ├── build_database.sh    # Process with DuckDB
│   └── analyze.sh           # Claude analysis
├── Makefile
└── package.json
```

## GitHub Actions

The workflow runs daily at 8am UTC:
1. Downloads fresh USCG data
2. Processes incidents and runs Claude analysis
3. Commits updated database
4. Deploys to GitHub Pages

Requires `ANTHROPIC_AUTH_TOKEN` secret for Claude CLI authentication with Max plan.

## Local Development

For local runs with Claude CLI:
```bash
# Ensure you're logged in to Claude with Max plan
claude auth login

# Run pipeline
make data

# Preview
make preview
```
