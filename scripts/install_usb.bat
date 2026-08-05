@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "ROOT=%~dp0.."
set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set "APK=%ROOT%\releases\android\lion-battle-3d-v1.2.2-android.apk"

if not exist "%ADB%" (
  echo ERROR: ADB was not found.
  exit /b 2
)
if not exist "%APK%" (
  echo ERROR: Release APK was not found. Run export_android.bat first.
  exit /b 3
)

echo Connected Android devices:
set "DEVICE_LIST=%TEMP%\lion_battle_adb_devices.txt"
"%ADB%" devices -l > "%DEVICE_LIST%"
type "%DEVICE_LIST%"
"%ADB%" get-state 1>nul 2>nul
if errorlevel 1 (
  echo ERROR: No authorized Android device is connected.
  exit /b 4
)
findstr /C:"unauthorized" /C:"offline" "%DEVICE_LIST%" >nul
if not errorlevel 1 (
  echo ERROR: A connected device is unauthorized or offline. Authorize USB debugging and retry.
  exit /b 5
)

echo Installing without deleting existing game data...
"%ADB%" install -r "%APK%"
if errorlevel 1 exit /b 10

"%ADB%" shell am start -W -n com.savanna.lionbattle3d/com.godot.game.GodotAppLauncher
if errorlevel 1 exit /b 11
echo INSTALL_AND_LAUNCH_OK
exit /b 0
