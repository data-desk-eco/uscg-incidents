#!/bin/bash
set -euo pipefail

mkdir -p data

# USCG uses 2-digit years in filenames (CY25.xlsx, CY26.xlsx, etc.)
CURRENT_YY=$(date +%y)
PREVIOUS_YY=$(printf "%02d" $(( 10#$CURRENT_YY - 1 )))

echo "Downloading USCG NRC data..."

# nrc.uscg.mil is flaky/slow, so retry with generous timeouts
CURL="curl -sfL --connect-timeout 30 --max-time 600 --retry 6 --retry-delay 15 --retry-all-errors"

# Always download previous year (guaranteed to exist)
$CURL "https://nrc.uscg.mil/FOIAFiles/CY${PREVIOUS_YY}.xlsx" -o "data/CY${PREVIOUS_YY}.xlsx"
echo "Downloaded CY${PREVIOUS_YY}.xlsx"

# Try current year (may not exist yet early in the year)
if $CURL "https://nrc.uscg.mil/FOIAFiles/CY${CURRENT_YY}.xlsx" -o "data/CY${CURRENT_YY}.xlsx"; then
    # Verify it's a real xlsx, not an error page
    if file "data/CY${CURRENT_YY}.xlsx" | grep -q "HTML"; then
        echo "CY${CURRENT_YY}.xlsx not yet available (got HTML error page)"
        rm -f "data/CY${CURRENT_YY}.xlsx"
    else
        echo "Downloaded CY${CURRENT_YY}.xlsx"
    fi
else
    echo "CY${CURRENT_YY}.xlsx not yet available"
    rm -f "data/CY${CURRENT_YY}.xlsx"
fi
