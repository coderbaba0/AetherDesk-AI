@echo off
setlocal enabledelayedexpansion

set "BASE=%~dp0"
if "%BASE:~-1%"=="\" set "BASE=%BASE:~0,-1%"
set "PS=powershell.exe -ExecutionPolicy Bypass"

if not exist "%BASE%" (
    echo.
    echo [ERROR] Project folder not found:
    echo %BASE%
    echo.
    pause
    exit /b
)

if not exist "%BASE%\reports" mkdir "%BASE%\reports"
if not exist "%BASE%\logs" mkdir "%BASE%\logs"
if not exist "%BASE%\cache" mkdir "%BASE%\cache"
if not exist "%BASE%\activity-data" mkdir "%BASE%\activity-data"

call :WELCOME

:MENU
cls
color 0A
echo ==================================================
echo              AetherDesk AI Launcher
echo        Local AI Command Center for Windows
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.
echo Project Path:
echo %BASE%
echo.
echo Main Modules:
echo   1. Top 10 Trending AI / Open Source Tech Report
echo   2. System Health AI Report
echo   3. Start Activity Tracker  [opens in NEW terminal]
echo   4. Generate Activity Productivity Dashboard
echo   5. Open Reports Folder
echo.
echo Scheduler:
echo   6. Schedule Daily Trending AI Report
echo   7. Schedule Daily System Health Report
echo   8. Schedule Activity Tracker on Windows Login
echo   9. Schedule Weekly Productivity Report
echo.
echo Setup / Help:
echo   10. Check Ollama Status
echo   11. Ollama Install / Run Instructions
echo   12. Show Usage Instructions
echo   13. Remove Activity Tracker Login Schedule
echo.
echo   0. Exit
echo.
set /p choice=Choose option: 

if "%choice%"=="1" goto TREND
if "%choice%"=="2" goto HEALTH
if "%choice%"=="3" goto TRACKER
if "%choice%"=="4" goto PRODUCTIVITY
if "%choice%"=="5" goto OPEN_REPORTS
if "%choice%"=="6" goto SCHEDULE_TREND
if "%choice%"=="7" goto SCHEDULE_HEALTH
if "%choice%"=="8" goto SCHEDULE_TRACKER
if "%choice%"=="9" goto SCHEDULE_PRODUCTIVITY
if "%choice%"=="10" goto CHECK_OLLAMA
if "%choice%"=="11" goto OLLAMA_HELP
if "%choice%"=="12" goto USAGE
if "%choice%"=="13" goto REMOVE_TRACKER_SCHEDULE
if "%choice%"=="0" exit /b

echo.
echo Invalid option. Please choose again.
pause
goto MENU


:CHECK_OLLAMA_FUNC
where ollama >nul 2>nul
if errorlevel 1 (
    set "OLLAMA_OK=0"
    exit /b
)

curl -s http://localhost:11434/api/tags >nul 2>nul
if errorlevel 1 (
    set "OLLAMA_OK=2"
    exit /b
)

set "OLLAMA_OK=1"
exit /b


:OLLAMA_WARNING
echo.
echo --------------------------------------------------
echo Ollama is not ready.
echo --------------------------------------------------
if "%OLLAMA_OK%"=="0" (
    echo Status: Ollama is NOT installed.
    echo.
    echo Install Ollama from:
    echo https://ollama.com/download
)
if "%OLLAMA_OK%"=="2" (
    echo Status: Ollama is installed but server is NOT running.
    echo.
    echo Start Ollama in a new terminal:
    echo.
    echo   ollama serve
)
echo.
echo Required recommended model:
echo.
echo   ollama pull gemma3:1b
echo.
echo Notes:
echo - AI summary needs Ollama.
echo - Activity Tracker can collect app data without Ollama.
echo - Productivity dashboard can still show tracked data even if AI summary is unavailable.
echo.
pause
exit /b


:TREND
cls
color 0A
echo ==================================================
echo Top 10 Trending AI / Open Source Tech Report
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.

call :CHECK_OLLAMA_FUNC
if not "%OLLAMA_OK%"=="1" (
    call :OLLAMA_WARNING
    goto MENU
)

if not exist "%BASE%\run-agent.ps1" (
    echo [ERROR] run-agent.ps1 not found.
    echo Expected path:
    echo %BASE%\run-agent.ps1
    echo.
    pause
    goto MENU
)

cd /d "%BASE%"
%PS% -File "%BASE%\run-agent.ps1"

echo.
echo Trending AI report process finished.
echo Reports folder:
echo %BASE%\reports
echo.
pause
goto MENU


:HEALTH
cls
color 0A
echo ==================================================
echo System Health AI Report
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.

call :CHECK_OLLAMA_FUNC
if not "%OLLAMA_OK%"=="1" (
    echo Ollama is not ready.
    echo.
    echo The System Health module may still generate basic metrics,
    echo but AI diagnosis requires Ollama.
    echo.
    echo Use option 11 for Ollama setup instructions.
    echo.
    set /p runbasic=Do you still want to run System Health Report? [Y/N]: 
    if /I not "%runbasic%"=="Y" goto MENU
)

if not exist "%BASE%\run-health-ai.ps1" (
    echo [ERROR] run-health-ai.ps1 not found.
    echo Expected path:
    echo %BASE%\run-health-ai.ps1
    echo.
    pause
    goto MENU
)

cd /d "%BASE%"
%PS% -File "%BASE%\run-health-ai.ps1"

echo.
echo System Health report process finished.
echo Reports folder:
echo %BASE%\reports
echo.
pause
goto MENU


:TRACKER
cls
color 0A
echo ==================================================
echo Start Activity Tracker
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.
echo Activity Tracker will open in a NEW terminal window.
echo.
echo Important:
echo - Keep the tracker terminal window open to continue tracking.
echo - Closing the tracker window will stop activity tracking.
echo - This launcher menu will remain free.
echo - You can come back here and choose option 4 to generate report.
echo.
echo Recommended setup:
echo For best results, schedule Activity Tracker to start automatically
echo when Windows starts. Use option 8 from this launcher.
echo.
echo Manual scheduler command:
echo schtasks /Create /TN "AetherDesk Activity Tracker" /SC ONLOGON /TR "powershell.exe -ExecutionPolicy Bypass -WindowStyle Minimized -File \"%BASE%\activity-tracker.ps1\"" /F
echo.
echo Data will be saved in:
echo %BASE%\activity-data
echo.
echo After some time, generate report using:
echo Option 4 - Generate Activity Productivity Dashboard
echo.

if not exist "%BASE%\activity-tracker.ps1" (
    echo [ERROR] activity-tracker.ps1 not found.
    echo Expected path:
    echo %BASE%\activity-tracker.ps1
    echo.
    pause
    goto MENU
)

echo Starting Activity Tracker in a new terminal window...
echo.

start "AetherDesk Activity Tracker" powershell.exe -ExecutionPolicy Bypass -NoExit -File "%BASE%\activity-tracker.ps1"

echo Tracker started in a NEW terminal window.
echo.
echo Now this launcher is free.
echo You can choose option 4 anytime to generate productivity dashboard.
echo.
pause
goto MENU


:PRODUCTIVITY
cls
color 0A
echo ==================================================
echo Generate Activity Productivity Dashboard
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.
echo This will generate dashboard from currently available activity data.
echo Even if tracker ran for only 1 minute, report can be generated.
echo.
echo Data folder:
echo %BASE%\activity-data
echo.

if not exist "%BASE%\activity-report.ps1" (
    echo [ERROR] activity-report.ps1 not found.
    echo Expected path:
    echo %BASE%\activity-report.ps1
    echo.
    pause
    goto MENU
)

cd /d "%BASE%"
%PS% -File "%BASE%\activity-report.ps1"

echo.
echo Productivity dashboard process finished.
echo Reports folder:
echo %BASE%\reports
echo.
pause
goto MENU


:OPEN_REPORTS
cls
color 0A
echo ==================================================
echo Open Reports Folder
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.
if not exist "%BASE%\reports" mkdir "%BASE%\reports"
start "" "%BASE%\reports"
echo Reports folder opened:
echo %BASE%\reports
echo.
pause
goto MENU


:SCHEDULE_TREND
cls
color 0A
echo ==================================================
echo Schedule Daily Trending AI Report
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.
echo This will run the Trending AI report automatically every day.
echo.
echo Important:
echo - For scheduled mode, config.json should have:
echo   "askTopicOnRun": false
echo - Ollama should be installed and running for AI summary.
echo.
set /p stime=Enter daily time, example 09:00 : 
if "%stime%"=="" set "stime=09:00"

schtasks /Create /TN "AetherDesk Daily Trending Report" /SC DAILY /ST %stime% /TR "powershell.exe -ExecutionPolicy Bypass -File \"%BASE%\run-agent.ps1\"" /F

echo.
echo Daily Trending AI Report scheduled at %stime%.
echo.
echo Task name:
echo AetherDesk Daily Trending Report
echo.
pause
goto MENU


:SCHEDULE_HEALTH
cls
color 0A
echo ==================================================
echo Schedule Daily System Health Report
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.
echo This will run System Health Report automatically every day.
echo.
set /p htime=Enter daily time, example 10:00 : 
if "%htime%"=="" set "htime=10:00"

schtasks /Create /TN "AetherDesk Daily System Health" /SC DAILY /ST %htime% /TR "powershell.exe -ExecutionPolicy Bypass -File \"%BASE%\run-health-ai.ps1\"" /F

echo.
echo Daily System Health Report scheduled at %htime%.
echo.
echo Task name:
echo AetherDesk Daily System Health
echo.
pause
goto MENU


:SCHEDULE_TRACKER
cls
color 0A
echo ==================================================
echo Schedule Activity Tracker on Windows Login
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.
echo This is the recommended setup.
echo.
echo What it does:
echo - Starts Activity Tracker automatically when Windows starts.
echo - Runs it minimized in the background.
echo - Keeps collecting app usage data for productivity reports.
echo.
echo Data folder:
echo %BASE%\activity-data
echo.
echo Scheduler command:
echo schtasks /Create /TN "AetherDesk Activity Tracker" /SC ONLOGON /TR "powershell.exe -ExecutionPolicy Bypass -WindowStyle Minimized -File \"%BASE%\activity-tracker.ps1\"" /F
echo.

if not exist "%BASE%\activity-tracker.ps1" (
    echo [ERROR] activity-tracker.ps1 not found.
    echo Expected path:
    echo %BASE%\activity-tracker.ps1
    echo.
    pause
    goto MENU
)

schtasks /Create /TN "AetherDesk Activity Tracker" /SC ONLOGON /TR "powershell.exe -ExecutionPolicy Bypass -WindowStyle Minimized -File \"%BASE%\activity-tracker.ps1\"" /F

echo.
echo Activity Tracker has been scheduled on Windows login.
echo.
echo Next time you log in, tracking will start automatically.
echo.
echo To generate a report later:
echo Run this launcher and choose option 4.
echo.
pause
goto MENU


:SCHEDULE_PRODUCTIVITY
cls
color 0A
echo ==================================================
echo Schedule Weekly Productivity Report
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.
echo This will generate a weekly productivity dashboard.
echo Default: Sunday 20:00
echo.
echo Note:
echo The tracker should be running regularly for useful weekly data.
echo Recommended: First use option 8 to schedule tracker on login.
echo.
set /p ptime=Enter weekly report time, example 20:00 : 
if "%ptime%"=="" set "ptime=20:00"

schtasks /Create /TN "AetherDesk Weekly Productivity Report" /SC WEEKLY /D SUN /ST %ptime% /TR "powershell.exe -ExecutionPolicy Bypass -File \"%BASE%\activity-report.ps1\"" /F

echo.
echo Weekly Productivity Report scheduled every Sunday at %ptime%.
echo.
echo Task name:
echo AetherDesk Weekly Productivity Report
echo.
pause
goto MENU


:CHECK_OLLAMA
cls
color 0A
echo ==================================================
echo Ollama Status
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.

where ollama >nul 2>nul
if errorlevel 1 (
    echo Status: NOT INSTALLED
    echo.
    echo Install from:
    echo https://ollama.com/download
    echo.
    echo After installation, run:
    echo ollama pull gemma3:1b
    echo.
    pause
    goto MENU
)

echo Ollama command found.
echo.

curl -s http://localhost:11434/api/tags > "%TEMP%\aetherdesk-ollama-tags.json" 2>nul
if errorlevel 1 (
    echo Status: INSTALLED BUT SERVER NOT RUNNING
    echo.
    echo Start Ollama:
    echo.
    echo   ollama serve
    echo.
    echo Then pull model:
    echo.
    echo   ollama pull gemma3:1b
    echo.
    pause
    goto MENU
)

echo Status: RUNNING
echo.
echo Installed models:
echo --------------------------------------------------
ollama list
echo --------------------------------------------------
echo.
echo Recommended model:
echo gemma3:1b
echo.
pause
goto MENU


:OLLAMA_HELP
cls
color 0A
echo ==================================================
echo Ollama Install / Run Instructions
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.
echo 1. Download Ollama:
echo    https://ollama.com/download
echo.
echo 2. Install Ollama for Windows.
echo.
echo 3. Open PowerShell and run:
echo.
echo    ollama serve
echo.
echo 4. In another PowerShell, pull small local model:
echo.
echo    ollama pull gemma3:1b
echo.
echo 5. Test model:
echo.
echo    ollama run gemma3:1b "hello"
echo.
echo 6. Then run this launcher again.
echo.
echo Notes:
echo - Activity Tracker can collect app data without Ollama.
echo - Productivity dashboard can show graphs without Ollama.
echo - AI summary requires Ollama.
echo - Trending AI and System Health AI reports work best with Ollama.
echo.
pause
goto MENU


:USAGE
cls
color 0A
echo ==================================================
echo AetherDesk AI Usage Instructions
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.
echo MODULE 1: Trending AI / Open Source Tech Report
echo ------------------------------------------------
echo Use option 1.
echo It searches public resources and uses local AI to summarize.
echo.
echo Config file:
echo %BASE%\config.json
echo.
echo Edit topic in config.json:
echo "topics": [ "open source AI agents" ]
echo.
echo For scheduler, set:
echo "askTopicOnRun": false
echo.
echo Output:
echo %BASE%\reports
echo.
echo.
echo MODULE 2: System Health AI Report
echo ---------------------------------
echo Use option 2.
echo It checks:
echo - Wi-Fi
echo - Bluetooth
echo - Internet / DNS
echo - CPU
echo - RAM
echo - Disk
echo - Battery
echo - Top processes
echo.
echo Output:
echo %BASE%\reports
echo.
echo.
echo MODULE 3: Activity Tracker + Productivity Dashboard
echo ----------------------------------------------------
echo Step 1:
echo Choose option 3.
echo Activity Tracker opens in a NEW terminal window.
echo Keep that tracker window open.
echo.
echo Step 2:
echo Work normally on your computer.
echo.
echo Step 3:
echo Come back to this launcher.
echo Choose option 4 to generate productivity dashboard.
echo.
echo Data folder:
echo %BASE%\activity-data
echo.
echo Output:
echo %BASE%\reports
echo.
echo.
echo RECOMMENDED ACTIVITY TRACKER SETUP
echo ----------------------------------
echo Choose option 8 to start tracker automatically on Windows login.
echo.
echo Manual command:
echo schtasks /Create /TN "AetherDesk Activity Tracker" /SC ONLOGON /TR "powershell.exe -ExecutionPolicy Bypass -WindowStyle Minimized -File \"%BASE%\activity-tracker.ps1\"" /F
echo.
echo Remove tracker scheduler:
echo schtasks /Delete /TN "AetherDesk Activity Tracker" /F
echo.
echo.
echo MANUAL COMMANDS
echo ---------------
echo Start activity tracker:
echo powershell -ExecutionPolicy Bypass -File "%BASE%\activity-tracker.ps1"
echo.
echo Generate productivity dashboard:
echo powershell -ExecutionPolicy Bypass -File "%BASE%\activity-report.ps1"
echo.
echo Generate system health report:
echo powershell -ExecutionPolicy Bypass -File "%BASE%\run-health-ai.ps1"
echo.
echo Generate trending AI report:
echo powershell -ExecutionPolicy Bypass -File "%BASE%\run-agent.ps1"
echo.
pause
goto MENU


:REMOVE_TRACKER_SCHEDULE
cls
color 0A
echo ==================================================
echo Remove Activity Tracker Login Schedule
echo ==================================================
echo.
echo Built by: flutterfever.com
echo.
echo This will remove the automatic Windows login schedule
echo for Activity Tracker.
echo.
set /p confirm=Are you sure? [Y/N]: 
if /I not "%confirm%"=="Y" goto MENU

schtasks /Delete /TN "AetherDesk Activity Tracker" /F

echo.
echo Activity Tracker login schedule removed.
echo.
pause
goto MENU


:WELCOME
cls
color 0A

set "bar="
for /L %%i in (1,1,20) do (
    set "bar=!bar!#"
    cls
    echo.
    echo     ==========================================================
    echo.
    echo                  A E T H E R D E S K   A I
    echo.
    echo          Local AI Command Center for Windows
    echo.
    echo     ==========================================================
    echo.
    echo          Loading: !bar!
    echo.
    echo          Built by: flutterfever.com
    echo.
    ping -n 1 127.0.0.1 >nul
)

cls
echo.
echo     ==========================================================
echo.
echo                  A E T H E R D E S K   A I
echo.
echo          Local AI Command Center for Windows
echo.
echo     ==========================================================
echo.
echo          Welcome to your local AI command center.
echo.
echo          Built by: flutterfever.com
echo.
echo     ==========================================================
echo.
ping -n 2 127.0.0.1 >nul
exit /b
