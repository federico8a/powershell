@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "ACTION=%~1"
set "WAVE=%~2"
if "%WAVE%"=="" set "WAVE=W1"
if "%ACTION%"=="" goto HELP
if /I "%ACTION%"=="preflight" goto PRE
if /I "%ACTION%"=="inventory" goto INV
if /I "%ACTION%"=="provision-preview" goto PRV
if /I "%ACTION%"=="provision-apply" goto PRA
if /I "%ACTION%"=="scan" goto SCAN
if /I "%ACTION%"=="initial" goto INITIAL
if /I "%ACTION%"=="delta" goto DELTA
if /I "%ACTION%"=="validate" goto VALIDATE
goto HELP
:PRE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\00-Preflight.ps1" -Manifest "%ROOT%config\sites.csv"
exit /b %ERRORLEVEL%
:INV
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\01-Inventory-OnPrem.ps1" -OutputPath "%ROOT%output"
exit /b %ERRORLEVEL%
:PRV
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\02-Provision-Targets.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%"
exit /b %ERRORLEVEL%
:PRA
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\02-Provision-Targets.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Apply
exit /b %ERRORLEVEL%
:SCAN
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\03-Run-SPMT.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Mode Scan
exit /b %ERRORLEVEL%
:INITIAL
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\03-Run-SPMT.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Mode Initial
exit /b %ERRORLEVEL%
:DELTA
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\03-Run-SPMT.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Mode Delta
exit /b %ERRORLEVEL%
:VALIDATE
where pwsh.exe >nul 2>&1
if errorlevel 1 (echo ERROR: pwsh 7.4+ is required for PnP validation. & exit /b 3)
pwsh.exe -NoProfile -File "%ROOT%scripts\04-Validate-Online.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -SourceLists "%ROOT%output\source-lists.csv" -OutputPath "%ROOT%output"
exit /b %ERRORLEVEL%
:HELP
echo Usage: run.cmd preflight ^| inventory ^| provision-preview [wave] ^| provision-apply [wave] ^| scan [wave] ^| initial [wave] ^| delta [wave] ^| validate [wave]
echo Copy config\sites.example.csv to config\sites.csv and review the runbook before executing.
exit /b 2
