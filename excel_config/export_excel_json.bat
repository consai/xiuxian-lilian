@echo off
setlocal
cd /d "%~dp0"

:: =======================================
:: 导出前清理目标路径
:: =======================================
set "CONTENT_OUT=C:\godot\xiuxian\data\exportjson"
set "PARAMS_OUT=C:\godot\xiuxian\data\exportjson\yunxing_params"

echo Cleaning export target directories...
if exist "%CONTENT_OUT%" (
    echo   Removing: %CONTENT_OUT%\*.json
    del /q "%CONTENT_OUT%\*.json" 2>nul
    for /d %%d in ("%CONTENT_OUT%\*") do (
        echo   Removing: %%d
        rd /s /q "%%d" 2>nul
    )
)
if exist "%PARAMS_OUT%" (
    echo   Removing: %PARAMS_OUT%\*.json
    del /q "%PARAMS_OUT%\*.json" 2>nul
)
echo Cleanup done.
echo.

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
