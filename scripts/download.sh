#!/bin/bash
set -euo pipefail

mkdir -p data

echo "Downloading USCG NRC data..."
curl -sL https://nrc.uscg.mil/FOIAFiles/CY25.xlsx -o data/CY25.xlsx
echo "Downloaded CY25.xlsx"
