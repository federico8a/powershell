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
if /I "%ACTION%"=="status" goto STATUS
if /I "%ACTION%"=="reset-session" goto RESET
if /I "%ACTION%"=="validate" goto VALIDATE
if /I "%ACTION%"=="identity-check" goto IDENTITY
goto HELP
:PRE
powershell.exe -NoProfile -File "%ROOT%scripts\00-Preflight.ps1" -Manifest "%ROOT%config\sites.csv"
exit /b %ERRORLEVEL%
:INV
powershell.exe -NoProfile -File "%ROOT%scripts\01-Inventory-OnPrem.ps1" -OutputPath "%ROOT%output"
exit /b %ERRORLEVEL%
:PRV
powershell.exe -NoProfile -File "%ROOT%scripts\02-Provision-Targets.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%"
exit /b %ERRORLEVEL%
:PRA
powershell.exe -NoProfile -File "%ROOT%scripts\02-Provision-Targets.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Apply
exit /b %ERRORLEVEL%
:SCAN
if defined SPMT_USER_MAPPING (
  powershell.exe -NoProfile -File "%ROOT%scripts\03-Run-SPMT.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Mode Scan -UserMappingFile "%SPMT_USER_MAPPING%"
) else (
  powershell.exe -NoProfile -File "%ROOT%scripts\03-Run-SPMT.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Mode Scan
)
exit /b %ERRORLEVEL%
:INITIAL
set "SPMT_USER_MAPPING_ARGS="
if defined SPMT_USER_MAPPING set "SPMT_USER_MAPPING_ARGS=-UserMappingFile ^"%SPMT_USER_MAPPING%^""
if defined SPMT_USER_MAPPING (
  powershell.exe -NoProfile -File "%ROOT%scripts\03-Run-SPMT.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Mode Initial -UserMappingFile "%SPMT_USER_MAPPING%"
) else (
  powershell.exe -NoProfile -File "%ROOT%scripts\03-Run-SPMT.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Mode Initial
)
exit /b %ERRORLEVEL%
:STATUS
powershell.exe -NoProfile -File "%ROOT%scripts\03-Run-SPMT.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Mode Status
exit /b %ERRORLEVEL%
:RESET
powershell.exe -NoProfile -File "%ROOT%scripts\03-Run-SPMT.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Mode ResetSession
exit /b %ERRORLEVEL%
:DELTA
powershell.exe -NoProfile -File "%ROOT%scripts\03-Run-SPMT.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -Mode Delta
exit /b %ERRORLEVEL%
:VALIDATE
where pwsh.exe >nul 2>&1
if errorlevel 1 (echo ERROR: pwsh 7.4+ is required for PnP validation. & exit /b 3)
pwsh.exe -NoProfile -File "%ROOT%scripts\04-Validate-Online.ps1" -Manifest "%ROOT%config\sites.csv" -Wave "%WAVE%" -SourceLists "%ROOT%output\source-lists.csv" -OutputPath "%ROOT%output"
exit /b %ERRORLEVEL%
:IDENTITY
if not defined SPMT_USER_MAPPING (echo ERROR: Set SPMT_USER_MAPPING path to approved no-header mapping CSV. & exit /b 3)
where pwsh.exe >nul 2>&1
if errorlevel 1 (echo ERROR: pwsh 7.4+ required. & exit /b 3)
pwsh.exe -NoProfile -File "%ROOT%scripts\05-Check-Identity-Mapping.ps1" -UserMappingFile "%SPMT_USER_MAPPING%" -OutputPath "%ROOT%output"
exit /b %ERRORLEVEL%
:HELP
echo Usage: run.cmd preflight ^| inventory ^| provision-preview [wave] ^| provision-apply [wave] ^| scan [wave] ^| initial [wave] ^| delta [wave] ^| validate [wave] ^| identity-check ^| status [wave] ^| reset-session [wave]
echo Copy config\sites.example.csv to config\sites.csv and review the runbook before executing.
exit /b 2
