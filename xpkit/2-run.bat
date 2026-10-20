@echo off
rem One test run. Starts the fake IRC server, then YOU double-click bitcoin.exe
rem (Hal launched it by double-click; from a cygwin shell it did not crash).
setlocal
set KIT=%~dp0
cd /d "%KIT%"
rem fresh Bitcoin data, as on Hal's first run
if exist "%APPDATA%\Bitcoin" rmdir /s /q "%APPDATA%\Bitcoin"
if exist debug.log del debug.log
if exist db.log del db.log
start "fakeircd" "%KIT%fakeircd.exe"
echo.
echo The fake IRC server is running in its own window.
echo Now DOUBLE-CLICK bitcoin.exe in the Explorer window that opens.
echo About 10-40 s later Bitcoin should crash (Dr. Watson writes its log silently).
echo Then close the fakeircd window and run 3-collect.bat.
explorer "%KIT%"
pause
