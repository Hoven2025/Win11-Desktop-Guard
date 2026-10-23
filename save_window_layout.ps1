# ==============================================================================
# Win11-Desktop-Guard: Window-Desktop-Memory (Save Layout & Dashboard)
# Captures all open windows across all virtual desktops, pinned states,
# monitor coordinates, and open File Explorer folder paths.
# ==============================================================================
param(
    [switch]$UpdateDashboard = $true
)

$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Web
$guardDir = $PSScriptRoot
$dllPath = Join-Path (Join-Path $guardDir "bin") "DesktopGuard.dll"
$configPath = Join-Path $guardDir "desktop_config.json"
$layoutPath = Join-Path $guardDir "window_layout.json"
$prevLayoutPath = Join-Path $guardDir "window_layout.prev.json"
$dashboardPath = Join-Path $guardDir "desktop_guard_dashboard.html"
$logPath = Join-Path $guardDir "desktop_guard.log"
$isDe = (Get-UICulture).TwoLetterISOLanguageName -eq "de"

function Write-GuardLog([string]$msgDe, [string]$msgEn) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = if ($isDe) { $msgDe } elseif ($msgEn) { $msgEn } else { $msgDe }
    $line = "[$ts] [WindowSave] $msg"
    Write-Host $line
    Add-Content -Path $logPath -Value $line -Encoding UTF8
}

if (-not (Test-Path $configPath)) {
    & (Join-Path $guardDir "restore_wallpapers.ps1")
}

Add-Type -Path $dllPath
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$deskMap = @{}
foreach ($d in $config.Desktops) {
    $deskMap[$d.Guid.ToUpper()] = @{ Index = $d.Index; Name = $d.Name; Wallpaper = $d.Wallpaper }
}

$explorerPaths = @{}
try {
    $shell = New-Object -ComObject Shell.Application
    foreach ($sw in $shell.Windows()) {
        try {
            $hwnd = [int64]$sw.HWND
            $path = $sw.Document.Folder.Self.Path
            if ($hwnd -and $path) {
                $explorerPaths[$hwnd] = $path
            }
        } catch {}
    }
} catch {}

$wins = [DesktopGuard.Win32Helper]::GetTopLevelWindows()
$outList = foreach ($w in $wins) {
    if ($w.ClassName -eq "Windows.UI.Core.CoreWindow") { continue }

    $gStr = "{" + $w.DesktopId.ToString().ToUpper() + "}"
    $pinMode = "None"
    if ($gStr -eq "{BB64D5B7-4DE3-4AB2-A87C-DB7601AEA7DC}") {
        $dIndex = -1
        $dName = if ($isDe) { "Alle Desktops (Fenster angeheftet)" } else { "All Desktops (Window Pinned)" }
        $pinMode = "Window"
    } elseif ($gStr -eq "{C2DDEA68-66F2-4CF9-8264-1BFD00FBBBAC}") {
        $dIndex = -2
        $dName = if ($isDe) { "Alle Desktops (App angeheftet)" } else { "All Desktops (App Pinned)" }
        $pinMode = "App"
    } elseif ($deskMap.ContainsKey($gStr)) {
        $dIndex = $deskMap[$gStr].Index
        $dName = $deskMap[$gStr].Name
    } else {
        $dIndex = 0
        $dName = "Unknown ($gStr)"
    }

    $proc = Get-Process -Id $w.Pid -ErrorAction SilentlyContinue
    $procName = if ($proc) { $proc.Name } else { "Unknown" }
    $exePath = if ($proc -and $proc.Path) { $proc.Path } else { "" }
    $folderPath = if ($explorerPaths.ContainsKey($w.Hwnd)) { $explorerPaths[$w.Hwnd] } else { "" }

    [PSCustomObject]@{
        DesktopIndex = $dIndex
        DesktopName  = $dName
        DesktopGuid  = $gStr
        PinMode      = $pinMode
        ProcessName  = $procName
        Executable   = $exePath
        FolderPath   = $folderPath
        PID          = $w.Pid
        Hwnd         = $w.Hwnd
        ClassName    = $w.ClassName
        Title        = $w.Title
        Left         = $w.Left
        Top          = $w.Top
        Width        = $w.Width
        Height       = $w.Height
        ShowCmd      = $w.ShowCmd
        SavedAt      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
}

$outArray = @($outList)
if ($outArray.Count -ge 2) {
    if (Test-Path $layoutPath) {
        Copy-Item -Path $layoutPath -Destination $prevLayoutPath -Force
    }
    $jsonOut = ConvertTo-Json -InputObject $outArray -Depth 5
    [System.IO.File]::WriteAllText($layoutPath, $jsonOut, [System.Text.Encoding]::UTF8)
    Write-GuardLog "$($outArray.Count) offene Fenster über alle Desktops gespeichert." "Saved $($outArray.Count) open windows across all desktops."
}

if ($UpdateDashboard -and $outArray.Count -gt 0) {
    $titleStr = if ($isDe) { "Win11-Desktop-Guard – Live-Status deiner Virtuellen Desktops" } else { "Win11-Desktop-Guard – Virtual Desktops Live Status" }
    $subStr = if ($isDe) { "Zuletzt aktualisiert: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss') | $($config.Desktops.Count) Virtuelle Desktops & $($outArray.Count) aktive Fenster" } else { "Last updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $($config.Desktops.Count) Virtual Desktops & $($outArray.Count) active windows" }
    $pinHeader = if ($isDe) { "📌 Auf allen Desktops angeheftet" } else { "📌 Pinned to All Desktops" }
    $emptyMsg = if ($isDe) { "Keine exklusiven Fenster auf diesem Desktop geöffnet" } else { "No exclusive windows open on this desktop" }
    $winWord = if ($isDe) { "Fenster" } else { "windows" }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine(@"
<!DOCTYPE html>
<html lang="$((Get-UICulture).TwoLetterISOLanguageName)">
<head>
<meta charset="UTF-8">
<title>$titleStr</title>
<style>
  :root { --bg: #0f172a; --card: #1e293b; --border: #334155; --text: #f8fafc; --muted: #94a3b8; --accent: #38bdf8; --pin: #f59e0b; }
  body { font-family: 'Segoe UI', system-ui, sans-serif; background: var(--bg); color: var(--text); margin: 0; padding: 32px; line-height: 1.5; }
  .container { max-width: 1280px; margin: 0 auto; }
  h1 { font-size: 1.8rem; margin-bottom: 6px; }
  .subtitle { color: var(--muted); margin-bottom: 28px; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(560px, 1fr)); gap: 20px; }
  .desktop-card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; overflow: hidden; display: flex; flex-direction: column; }
  .wp-banner { height: 110px; background-size: cover; background-position: center; position: relative; display: flex; align-items: flex-end; padding: 12px 16px; border-bottom: 1px solid var(--border); }
  .wp-overlay { position: absolute; inset: 0; background: linear-gradient(to top, rgba(15,23,42,0.92), rgba(15,23,42,0.25)); }
  .wp-title { position: relative; z-index: 1; display: flex; justify-content: space-between; width: 100%; align-items: baseline; }
  .wp-title h2 { margin: 0; font-size: 1.25rem; color: var(--accent); }
  .wp-path { font-size: 0.75rem; color: #cbd5e1; position: relative; z-index: 1; }
  .win-list { padding: 14px 16px; margin: 0; list-style: none; flex: 1; }
  .win-item { padding: 7px 0; border-bottom: 1px solid rgba(51,65,85,0.45); font-size: 0.88rem; display: flex; justify-content: space-between; gap: 10px; }
  .win-item:last-child { border-bottom: none; }
  .proc-badge { background: rgba(56,189,248,0.15); color: var(--accent); padding: 1px 7px; border-radius: 4px; font-weight: 600; font-size: 0.75rem; margin-right: 8px; white-space: nowrap; }
  .pin-badge { background: rgba(245,158,11,0.2); color: var(--pin); padding: 1px 7px; border-radius: 4px; font-weight: 600; font-size: 0.75rem; margin-right: 8px; }
  .coords { color: var(--muted); font-size: 0.75rem; white-space: nowrap; }
</style>
</head>
<body>
<div class="container">
  <h1>🛡️ $titleStr</h1>
  <p class="subtitle">$subStr</p>
  <div class="grid">
"@)

    $pinnedWins = @($outArray | Where-Object { $_.DesktopIndex -lt 0 })
    if ($pinnedWins.Count -gt 0) {
        [void]$sb.AppendLine("    <div class='desktop-card' style='grid-column: 1 / -1; border-color: rgba(245,158,11,0.5);'>")
        [void]$sb.AppendLine("      <div class='wp-banner' style='height:54px; background:#1e293b;'><div class='wp-title'><h2 style='color:#f59e0b'>$pinHeader ($($pinnedWins.Count) $winWord)</h2></div></div>")
        [void]$sb.AppendLine("      <ul class='win-list'>")
        foreach ($pw in $pinnedWins) {
            $t = [System.Web.HttpUtility]::HtmlEncode($pw.Title)
            $extra = if ($pw.FolderPath) { " <small style='color:#38bdf8'>[$($pw.FolderPath)]</small>" } else { "" }
            [void]$sb.AppendLine("        <li class='win-item'><div><span class='pin-badge'>$($pw.PinMode)-Pin</span><span class='proc-badge'>$($pw.ProcessName)</span>$t$extra</div><span class='coords'>$($pw.Left),$($pw.Top) ($($pw.Width)x$($pw.Height))</span></li>")
        }
        [void]$sb.AppendLine("      </ul></div>")
    }

    foreach ($d in ($config.Desktops | Sort-Object Index)) {
        $dWins = @($outArray | Where-Object { $_.DesktopIndex -eq $d.Index })
        $wpUrl = if ($d.Wallpaper) { "file:///" + ($d.Wallpaper -replace "\\","/" -replace "'","%27") } else { "" }
        $wpFile = if ($d.Wallpaper) { Split-Path $d.Wallpaper -Leaf } else { "Default" }
        [void]$sb.AppendLine("    <div class='desktop-card'>")
        [void]$sb.AppendLine("      <div class='wp-banner' style=`"background-image:url('$wpUrl')`"><div class='wp-overlay'></div><div style='width:100%'><div class='wp-title'><h2>Desktop $($d.Index): $($d.Name)</h2><span class='wp-path'>$($dWins.Count) $winWord</span></div><div class='wp-path'>🖼️ $wpFile</div></div></div>")
        [void]$sb.AppendLine("      <ul class='win-list'>")
        if ($dWins.Count -eq 0) {
            [void]$sb.AppendLine("        <li class='win-item' style='color:#64748b'>$emptyMsg</li>")
        } else {
            foreach ($w in $dWins) {
                $t = [System.Web.HttpUtility]::HtmlEncode($w.Title)
                $extra = if ($w.FolderPath) { " <small style='color:#38bdf8'>[$($w.FolderPath)]</small>" } else { "" }
                [void]$sb.AppendLine("        <li class='win-item'><div><span class='proc-badge'>$($w.ProcessName)</span>$t$extra</div><span class='coords'>$($w.Left),$($w.Top) ($($w.Width)x$($w.Height))</span></li>")
            }
        }
        [void]$sb.AppendLine("      </ul></div>")
    }

    [void]$sb.AppendLine("  </div></div></body></html>")
    [System.IO.File]::WriteAllText($dashboardPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
}
