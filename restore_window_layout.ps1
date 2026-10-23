# ==============================================================================
# Win11-Desktop-Guard: Window-Desktop-Restore
# Restores all virtual desktop wallpapers and moves open windows back to their
# saved virtual desktops (including pinned states and monitor coordinates).
# ==============================================================================
param(
    [switch]$ReopenExplorerFolders = $true,
    [switch]$RestorePositions = $true,
    [int]$StartupDelaySeconds = 0
)

$ErrorActionPreference = "Continue"
$guardDir = $PSScriptRoot
$binDir = Join-Path $guardDir "bin"
$dllPath = Join-Path $binDir "DesktopGuard.dll"
$vdExe = Join-Path $binDir "VirtualDesktop11.exe"
$configPath = Join-Path $guardDir "desktop_config.json"
$layoutPath = Join-Path $guardDir "window_layout.json"
$logPath = Join-Path $guardDir "desktop_guard.log"
$isDe = (Get-UICulture).TwoLetterISOLanguageName -eq "de"

function Write-GuardLog([string]$msgDe, [string]$msgEn) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = if ($isDe) { $msgDe } elseif ($msgEn) { $msgEn } else { $msgDe }
    $line = "[$ts] [WindowRestore] $msg"
    Write-Host $line
    Add-Content -Path $logPath -Value $line -Encoding UTF8
}

if ($StartupDelaySeconds -gt 0) {
    Write-GuardLog "Warte $StartupDelaySeconds Sekunden auf den Start aller Programme..." "Waiting $StartupDelaySeconds seconds for startup applications..."
    Start-Sleep -Seconds $StartupDelaySeconds
}

# 1. Restore all virtual desktop wallpapers & names first
& (Join-Path $guardDir "restore_wallpapers.ps1") -ForceRestore

if (-not (Test-Path $layoutPath)) {
    Write-GuardLog "Keine gespeicherte window_layout.json gefunden." "No saved window_layout.json found."
    exit 0
}

Add-Type -Path $dllPath
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$maxDesktops = if ($config -and $config.Desktops) { $config.Desktops.Count } else { 32 }
$savedWins = @(Get-Content $layoutPath -Raw -Encoding UTF8 | ConvertFrom-Json)

# 2. Reopen closed File Explorer folders if enabled
if ($ReopenExplorerFolders) {
    $savedExplorers = @($savedWins | Where-Object { $_.ProcessName -eq "explorer" -and $_.ClassName -eq "CabinetWClass" -and $_.FolderPath })
    if ($savedExplorers.Count -gt 0) {
        $openPaths = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
        try {
            $shell = New-Object -ComObject Shell.Application
            foreach ($sw in $shell.Windows()) {
                try {
                    $p = $sw.Document.Folder.Self.Path
                    if ($p) { [void]$openPaths.Add($p) }
                } catch {}
            }
        } catch {}

        $openedNew = $false
        foreach ($se in $savedExplorers) {
            if (-not $openPaths.Contains($se.FolderPath) -and (Test-Path -LiteralPath $se.FolderPath)) {
                Write-GuardLog "Öffne gespeicherten Explorer-Ordner: $($se.FolderPath)" "Reopening saved File Explorer folder: $($se.FolderPath)"
                Start-Process "explorer.exe" -ArgumentList "`"$($se.FolderPath)`""
                [void]$openPaths.Add($se.FolderPath)
                $openedNew = $true
            }
        }
        if ($openedNew) { Start-Sleep -Seconds 2 }
    }
}

# 3. Enumerate current windows and match with saved layout
$liveWins = @([DesktopGuard.Win32Helper]::GetTopLevelWindows() | Where-Object { $_.ClassName -ne "Windows.UI.Core.CoreWindow" })
$liveWithProc = foreach ($lw in $liveWins) {
    $p = Get-Process -Id $lw.Pid -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Hwnd        = $lw.Hwnd
        Pid         = $lw.Pid
        ProcessName = if ($p) { $p.Name } else { "Unknown" }
        ClassName   = $lw.ClassName
        Title       = $lw.Title
        DesktopGuid = "{" + $lw.DesktopId.ToString().ToUpper() + "}"
        Left        = $lw.Left
        Top         = $lw.Top
        Width       = $lw.Width
        Height      = $lw.Height
    }
}

$usedHwnds = New-Object System.Collections.Generic.HashSet[int64]
$movedCount = 0
$posCount = 0

foreach ($sw in $savedWins) {
    $candidates = @($liveWithProc | Where-Object {
        (-not $usedHwnds.Contains($_.Hwnd)) -and
        ($_.ProcessName -eq $sw.ProcessName) -and
        ($_.ClassName -eq $sw.ClassName)
    })

    if ($candidates.Count -eq 0) { continue }

    $best = $null
    $bestScore = -1

    foreach ($c in $candidates) {
        $score = 0
        if ($c.Title -eq $sw.Title) {
            $score += 100
        } elseif ($c.Title -and $sw.Title) {
            $cleanSaved = $sw.Title -replace '^\(\d+\)\s*', ''
            $cleanLive  = $c.Title -replace '^\(\d+\)\s*', ''
            if ($cleanSaved -eq $cleanLive) {
                $score += 80
            } elseif ($c.Title.Contains($sw.Title) -or $sw.Title.Contains($c.Title)) {
                $score += 50
            }
        }
        $dist = [Math]::Abs($c.Left - $sw.Left) + [Math]::Abs($c.Top - $sw.Top)
        if ($dist -lt 50) { $score += 30 }
        elseif ($dist -lt 300) { $score += 10 }

        if ($score -gt $bestScore) {
            $bestScore = $score
            $best = $c
        }
    }

    if ($sw.ProcessName -match '^(chrome|msedge|brave|firefox)$' -and $bestScore -lt 30) { continue }

    if ($best) {
        [void]$usedHwnds.Add($best.Hwnd)

        if ($best.DesktopGuid -ne $sw.DesktopGuid) {
            if ($sw.PinMode -eq "Window" -or $sw.DesktopIndex -eq -1) {
                & $vdExe /Quiet "/PinWindowHandle:$($best.Hwnd)" | Out-Null
                Write-GuardLog "Fenster angeheftet (Alle Desktops): [$($sw.ProcessName)] '$($best.Title)'" "Pinned window (All Desktops): [$($sw.ProcessName)] '$($best.Title)'"
                $movedCount++
            } elseif ($sw.PinMode -eq "App" -or $sw.DesktopIndex -eq -2) {
                & $vdExe /Quiet "/PinApplication:$($best.Pid)" | Out-Null
                Write-GuardLog "App angeheftet (Alle Desktops): [$($sw.ProcessName)] '$($best.Title)'" "Pinned app (All Desktops): [$($sw.ProcessName)] '$($best.Title)'"
                $movedCount++
            } elseif ($sw.DesktopIndex -ge 1 -and $sw.DesktopIndex -le $maxDesktops) {
                $zeroIdx = $sw.DesktopIndex - 1
                & $vdExe /Quiet "/UnPinWindowHandle:$($best.Hwnd)" 2>$null | Out-Null
                & $vdExe /Quiet "/GetDesktop:$zeroIdx" "/MoveWindowHandle:$($best.Hwnd)" | Out-Null
                Write-GuardLog "Fenster verschoben nach Desktop $($sw.DesktopIndex) ($($sw.DesktopName)): [$($sw.ProcessName)] '$($best.Title)'" "Moved window to Desktop $($sw.DesktopIndex) ($($sw.DesktopName)): [$($sw.ProcessName)] '$($best.Title)'"
                $movedCount++
            }
        }

        if ($RestorePositions) {
            $posDiff = [Math]::Abs($best.Left - $sw.Left) + [Math]::Abs($best.Top - $sw.Top) + [Math]::Abs($best.Width - $sw.Width) + [Math]::Abs($best.Height - $sw.Height)
            if ($posDiff -gt 20 -and $sw.Width -gt 100 -and $sw.Height -gt 100) {
                [void][DesktopGuard.Win32Helper]::SetWindowPos([IntPtr]$best.Hwnd, [IntPtr]::Zero, $sw.Left, $sw.Top, $sw.Width, $sw.Height, 0x0014)
                $posCount++
            }
        }
    }
}

Write-GuardLog "Wiederherstellung abgeschlossen: $movedCount Fenster verschoben, $posCount Positionen korrigiert." "Restore complete: $movedCount windows moved, $posCount positions adjusted."
