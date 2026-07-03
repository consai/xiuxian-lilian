@echo off
setlocal
cd /d "%~dp0"

set "PY=C:\Users\36009\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"

if exist "%PY%" (
    "%PY%" "%CD%\export_excel_json.py" %*
) else (
    py -3 "%CD%\export_excel_json.py" %*
    if errorlevel 9009 python "%CD%\export_excel_json.py" %*
)

if errorlevel 1 (
    echo.
    echo Export failed.
    pause
    exit /b 1
)

echo.
echo Export complete.
