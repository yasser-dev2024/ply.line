@echo off
setlocal EnableExtensions
chcp 65001 >nul

call "%~dp0export_android.bat"
if errorlevel 1 exit /b %errorlevel%
call "%~dp0verify_apk.bat"
if errorlevel 1 exit /b %errorlevel%

set "ROOT=%~dp0.."
set "APK=%ROOT%\releases\android\lion-battle-3d-v1.2.2-android.apk"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$h=(Get-FileHash -LiteralPath '%APK%' -Algorithm SHA256).Hash.ToLowerInvariant(); [IO.File]::WriteAllText('%APK%.sha256', $h + '  lion-battle-3d-v1.2.2-android.apk', [Text.UTF8Encoding]::new($false)); Write-Output ('SHA256=' + $h)"
if errorlevel 1 exit /b 30
copy /y "%APK%.sha256" "%ROOT%\download_page\downloads\lion-battle-3d-v1.2.2-android.apk.sha256" >nul || exit /b 31
echo RELEASE_PREPARED_OK
exit /b 0
