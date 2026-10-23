@echo off
if not exist "%~dp0desktop_guard_dashboard.html" (
    if exist "C:\Program Files\PowerShell\7\pwsh.exe" (
        "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0save_window_layout.ps1"
    ) else (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0save_window_layout.ps1"
    )
)
start "" "%~dp0desktop_guard_dashboard.html"
