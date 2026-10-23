# ==============================================================================
# Win11-Desktop-Guard: Uninstaller (Removes Scheduled Tasks)
# ==============================================================================
$ErrorActionPreference = "Continue"
$isDe = (Get-UICulture).TwoLetterISOLanguageName -eq "de"

foreach ($t in @("DesktopGuard_LogonRestore", "DesktopGuard_PeriodicSync")) {
    Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
}

if ($isDe) {
    Write-Host "[OK] Die Hintergrundaufgaben von Win11-Desktop-Guard wurden aus der Windows-Aufgabenplanung entfernt." -ForegroundColor Yellow
} else {
    Write-Host "[OK] Win11-Desktop-Guard scheduled tasks have been removed from Windows Task Scheduler." -ForegroundColor Yellow
}
