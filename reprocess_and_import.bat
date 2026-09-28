@echo off
setlocal
cd /d %~dp0
python -m pip install -r requirements-data-pipeline.txt
if errorlevel 1 exit /b 1
python -m data_pipeline.cli process-wave1 --repo-root .
if errorlevel 1 exit /b 1
python -m data_pipeline.cli import-mysql --repo-root . --dry-run --sync-existing
if errorlevel 1 exit /b 1
echo.
echo Dry-run completed. Review datasets\reports\mysql_import_report.json
set /p CONFIRM=Import production-valid records into MySQL now? (Y/N):
if /I "%CONFIRM%"=="Y" python -m data_pipeline.cli import-mysql --repo-root . --sync-existing
endlocal
