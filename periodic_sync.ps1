$guardDir = $PSScriptRoot
& (Join-Path $guardDir "restore_wallpapers.ps1")
& (Join-Path $guardDir "save_window_layout.ps1")
