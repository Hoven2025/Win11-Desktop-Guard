# ==============================================================================
# Win11-Desktop-Guard: Installer (Task Scheduler Setup & Initial Snapshot)
# ==============================================================================
$ErrorActionPreference = "Stop"
$guardDir = $PSScriptRoot
$vbsPath = Join-Path $guardDir "run_hidden.vbs"
$restoreScript = Join-Path $guardDir "restore_window_layout.ps1"
$syncScript = Join-Path $guardDir "periodic_sync.ps1"
$isDe = (Get-UICulture).TwoLetterISOLanguageName -eq "de"

# 1. Initial Wallpaper & Desktop Config Discovery
& (Join-Path $guardDir "restore_wallpapers.ps1") -SaveCurrentAsDefault
& (Join-Path $guardDir "restore_wallpapers.ps1") -ForceRestore

# 2. Initial Window Layout Snapshot & Dashboard
& (Join-Path $guardDir "save_window_layout.ps1")

# 3. Register Scheduled Task 1: Restore on Windows Logon
$taskLogonName = "DesktopGuard_LogonRestore"
$actionLogon = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "//B //NoLogo `"$vbsPath`" `"$restoreScript`" `"-StartupDelaySeconds 12`""
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask -TaskName $taskLogonName -Action $actionLogon -Trigger $triggerLogon -Principal $principal -Settings $settings -Description "Restores virtual desktop wallpapers and window positions after logon." -Force | Out-Null

# 4. Register Scheduled Task 2: Periodic Sync & Auto-Heal (Every 5 Minutes)
$taskSyncName = "DesktopGuard_PeriodicSync"
$actionSync = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "//B //NoLogo `"$vbsPath`" `"$syncScript`""
$triggerSync = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)

Register-ScheduledTask -TaskName $taskSyncName -Action $actionSync -Trigger $triggerSync -Principal $principal -Settings $settings -Description "Automatically heals reset virtual desktop wallpapers and saves window positions." -Force | Out-Null

if ($isDe) {
    Write-Host "`n[OK] Win11-Desktop-Guard wurde erfolgreich installiert!" -ForegroundColor Green
    Write-Host "  - 'DesktopGuard_LogonRestore' : Stellt beim Windows-Start alle Hintergrundbilder & Fenster wieder her."
    Write-Host "  - 'DesktopGuard_PeriodicSync' : Speichert alle 5 Min. verschobene Fenster & heilt verstellte Hintergrundbilder."
} else {
    Write-Host "`n[OK] Win11-Desktop-Guard has been installed successfully!" -ForegroundColor Green
    Write-Host "  - 'DesktopGuard_LogonRestore' : Restores all wallpapers & window positions at Windows logon."
    Write-Host "  - 'DesktopGuard_PeriodicSync' : Saves moved window positions & heals reset wallpapers every 5 minutes."
}
