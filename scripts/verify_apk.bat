@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "ROOT=%~dp0.."
set "SDK=%LOCALAPPDATA%\Android\Sdk"
set "JAVA_HOME=%ROOT%\..\tools\java17\jdk-17.0.20+8"
set "PATH=%JAVA_HOME%\bin;%PATH%"
set "APK=%ROOT%\releases\android\lion-battle-3d-v1.2.2-android.apk"
set "AAPT=%SDK%\build-tools\35.0.1\aapt2.exe"
set "APKSIGNER=%SDK%\build-tools\35.0.1\apksigner.bat"
set "INFO=%TEMP%\lion_battle_apk_info.txt"
set "SIGN=%TEMP%\lion_battle_apk_sign.txt"

if not exist "%APK%" exit /b 2
for %%I in ("%APK%") do if %%~zI LSS 5000000 exit /b 3
if not exist "%AAPT%" exit /b 4
if not exist "%APKSIGNER%" exit /b 5

"%AAPT%" dump badging "%APK%" > "%INFO%" || exit /b 6
findstr /C:"package: name='com.savanna.lionbattle3d' versionCode='5' versionName='1.2.2'" "%INFO%" >nul || exit /b 7

call "%APKSIGNER%" verify --verbose --print-certs "%APK%" > "%SIGN%" || exit /b 8
findstr /C:"Verified" "%SIGN%" >nul || exit /b 9

echo PACKAGE_AND_VERSION_OK
type "%SIGN%"
certutil -hashfile "%APK%" SHA256
exit /b 0
