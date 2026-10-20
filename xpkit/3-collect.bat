@echo off
rem Gathers everything into .\results\run_<n>. Zip that folder (right click >
rem Send To > Compressed folder) and send it back.
setlocal enabledelayedexpansion
set KIT=%~dp0
cd /d "%KIT%"
set N=1
:next
if exist "results\run_!N!" (set /a N+=1 & goto next)
set OUT=results\run_!N!
mkdir "%OUT%"
copy /y debug.log "%OUT%\" >nul 2>&1
copy /y db.log "%OUT%\" >nul 2>&1
copy /y fakeircd.log "%OUT%\" >nul 2>&1
copy /y drwatson\drwtsn32.log "%OUT%\" >nul 2>&1
move /y drwatson\user.dmp "%OUT%\" >nul 2>&1
ver > "%OUT%\windows_version.txt"
systeminfo >> "%OUT%\windows_version.txt" 2>nul
dir /s "%OUT%"
echo.
echo Collected in %OUT%
pause
