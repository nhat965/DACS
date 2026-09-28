@echo off
setlocal
cd /d %~dp0
python -m pip install -r requirements-data-pipeline.txt
if errorlevel 1 exit /b 1
python -m data_pipeline.cli process-wave1 --repo-root .
endlocal
