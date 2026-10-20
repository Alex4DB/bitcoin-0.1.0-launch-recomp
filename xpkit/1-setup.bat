@echo off
rem Run ONCE, as an administrator, on the Windows XP SP3 test VM.
rem 1) chat.freenode.net -> 127.0.0.1 so Bitcoin 0.1.0 talks to fakeircd.exe
rem 2) Dr. Watson (built into XP) as the crash debugger, full dump, log in .\drwatson
setlocal
set KIT=%~dp0
set HOSTS=%SystemRoot%\system32\drivers\etc\hosts
findstr /i /c:"chat.freenode.net" "%HOSTS%" >nul || (echo 127.0.0.1 chat.freenode.net>>"%HOSTS%")
type "%HOSTS%" | findstr /i "freenode"
if not exist "%KIT%drwatson" mkdir "%KIT%drwatson"
drwtsn32 -i
set DW=HKLM\SOFTWARE\Microsoft\DrWatson
reg add %DW% /v LogFilePath /t REG_SZ /d "%KIT%drwatson" /f >nul
reg add %DW% /v CrashDumpFile /t REG_SZ /d "%KIT%drwatson\user.dmp" /f >nul
reg add %DW% /v CreateCrashDump /t REG_DWORD /d 1 /f >nul
reg add %DW% /v CrashDumpType /t REG_DWORD /d 1 /f >nul
reg add %DW% /v DumpAllThreads /t REG_DWORD /d 1 /f >nul
reg add %DW% /v AppendToLogFile /t REG_DWORD /d 1 /f >nul
reg add %DW% /v VisualNotification /t REG_DWORD /d 0 /f >nul
reg add %DW% /v SoundNotification /t REG_DWORD /d 0 /f >nul
reg add %DW% /v NumberOfInstructions /t REG_DWORD /d 16 /f >nul
reg add %DW% /v MaximumCrashes /t REG_DWORD /d 20 /f >nul
reg add %DW% /v DumpSymbols /t REG_DWORD /d 0 /f >nul
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug" /v Debugger
echo.
echo Setup done. Next: 2-run.bat
pause
