#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 -m pip install -r requirements-data-pipeline.txt
python3 -m data_pipeline.cli process-wave1 --repo-root .
python3 -m data_pipeline.cli import-mysql --repo-root . --dry-run --sync-existing
printf '\nDry-run completed. Review datasets/reports/mysql_import_report.json\n'
read -r -p 'Import/sync production-valid records into MySQL now? (y/N): ' ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  python3 -m data_pipeline.cli import-mysql --repo-root . --sync-existing
fi
