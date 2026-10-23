@echo off
setlocal
cd /d "%~dp0"
call build-a8.bat
if errorlevel 1 exit /b 1

if not exist "%~dp0quake.atr" (
  echo quake.atr missing after build
  exit /b 1
)
if not exist "C:\app\altirra\Altirra64.exe" (
  echo Altirra not found — quake.atr is built; run it manually.
  exit /b 0
)
start "" "C:\app\altirra\Altirra64.exe" /hardware:800xl /ntsc /nobasic /memsize:64K /w /diskemu:1050 /disk "%~dp0quake.atr"
