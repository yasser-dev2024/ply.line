@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul

set "ROOT=%~dp0.."
set "GODOT=%ROOT%\..\tools\godot\editor\Godot_v4.7.1-stable_win64_console.exe"
set "JAVA_HOME=%ROOT%\..\tools\java17\jdk-17.0.20+8"
set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
set "SECRET_FILE=%ROOT%\.secrets\release.properties"
set "BUILD_APK=%ROOT%\android_build\lion-battle-3d-v1.2.2-android.apk"
set "RELEASE_APK=%ROOT%\releases\android\lion-battle-3d-v1.2.2-android.apk"
set "WEB_APK=%ROOT%\download_page\downloads\lion-battle-3d-v1.2.2-android.apk"

if not exist "%GODOT%" (
  echo ERROR: Godot 4.7.1 was not found.
  exit /b 2
)
if not exist "%JAVA_HOME%\bin\java.exe" (
  echo ERROR: JDK 17 was not found.
  exit /b 3
)
if not exist "%ANDROID_HOME%\platform-tools\adb.exe" (
  echo ERROR: Android SDK was not found.
  exit /b 4
)
if not exist "%ROOT%\game\export_presets.cfg" (
  echo ERROR: Android export preset was not found.
  exit /b 5
)
if not exist "%SECRET_FILE%" (
  echo ERROR: Local release signing configuration is missing.
  echo Run scripts\create_release_key.ps1 once.
  exit /b 6
)

for /f "usebackq tokens=1,* delims==" %%A in ("%SECRET_FILE%") do set "%%A=%%B"
if not defined KEYSTORE_PATH exit /b 7
if not defined KEYSTORE_ALIAS exit /b 8
if not defined KEYSTORE_PASSWORD exit /b 9
if not exist "%KEYSTORE_PATH%" exit /b 10

set "GODOT_ANDROID_KEYSTORE_RELEASE_PATH=%KEYSTORE_PATH%"
set "GODOT_ANDROID_KEYSTORE_RELEASE_USER=%KEYSTORE_ALIAS%"
set "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=%KEYSTORE_PASSWORD%"
set "PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%"

if not exist "%ROOT%\android_build" mkdir "%ROOT%\android_build"
if not exist "%ROOT%\releases\android" mkdir "%ROOT%\releases\android"
if not exist "%ROOT%\download_page\downloads" mkdir "%ROOT%\download_page\downloads"

echo Exporting signed Android Release APK...
"%GODOT%" --headless --path "%ROOT%\game" --export-release "Android Release" "%BUILD_APK%"
if errorlevel 1 (
  echo ERROR: Godot Android export failed.
  exit /b 20
)
if not exist "%BUILD_APK%" (
  echo ERROR: Godot reported success but the APK is missing.
  exit /b 21
)

copy /y "%BUILD_APK%" "%RELEASE_APK%" >nul || exit /b 22
copy /y "%BUILD_APK%" "%WEB_APK%" >nul || exit /b 23
echo APK_READY=%RELEASE_APK%
exit /b 0
