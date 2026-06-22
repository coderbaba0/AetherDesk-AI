@echo off
setlocal
set "BASE=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%BASE%AetherDeskAI-UI.ps1"
