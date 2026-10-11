@echo off
cd /d "%~dp0..\.."
echo ==============================================
echo   Riftbound - Rojo Live Sync Server
echo ==============================================
echo Listening on localhost:34872...
tools\rojo\rojo.exe serve default.project.json
pause
