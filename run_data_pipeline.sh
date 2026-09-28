#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 -m pip install -r requirements-data-pipeline.txt
python3 -m data_pipeline.cli run-all --repo-root .
