# ==============================================================================
# Win11-Desktop-Guard: Smart Wallpaper-Lock & Auto-Heal (EN / DE)
# - Auto-discovers all Virtual Desktops on first run (Zero-Config).
# - Fixes the Windows 11 Virtual Desktop wallpaper reset/duplicate bug.
# - Automatically learns intentional wallpaper or desktop name changes.
# ==============================================================================
param(
    [switch]$ForceRestore,
    [switch]$SaveCurrentAsDefault
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$configPath = Join-Path $scriptDir "desktop_config.json"
$binDir = Join-Path $scriptDir "bin"
$vdExe = Join-Path $binDir "VirtualDesktop11.exe"
$dllPath = Join-Path $binDir "DesktopGuard.dll"
$logPath = Join-Path $scriptDir "desktop_guard.log"
$isDe = (Get-UICulture).TwoLetterISOLanguageName -eq "de"

function Write-GuardLog([string]$msgDe, [string]$msgEn) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = if ($isDe) { $msgDe } elseif ($msgEn) { $msgEn } else { $msgDe }
    $line = "[$ts] [WallpaperGuard] $msg"
    Write-Host $line
    Add-Content -Path $logPath -Value $line -Encoding UTF8
}

# Auto-compile binaries if missing (e.g., when cloned from git source)
$cscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if ((-not (Test-Path $vdExe) -or -not (Test-Path $dllPath)) -and (Test-Path $cscPath)) {
    if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir -Force | Out-Null }
    $srcDir = Join-Path $scriptDir "src"
    if (-not (Test-Path $dllPath) -and (Test-Path (Join-Path $srcDir "DesktopGuard.cs"))) {
        & $cscPath /nologo /target:library /out:$dllPath (Join-Path $srcDir "DesktopGuard.cs") | Out-Null
    }
    if (-not (Test-Path $vdExe) -and (Test-Path (Join-Path $srcDir "VirtualDesktop11-24H2.cs"))) {
        & $cscPath /nologo /out:$vdExe (Join-Path $srcDir "VirtualDesktop11-24H2.cs") | Out-Null
    }
}

$vdRootPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops"
$desktopsKeyPath = "$vdRootPath\Desktops"
if (-not (Test-Path $desktopsKeyPath)) {
    New-Item -Path $desktopsKeyPath -Force | Out-Null
}

# 1. Disable phantom slideshow bug in Windows 11 Registry
$wallpapersKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers"
if (Test-Path $wallpapersKey) {
    $wpProps = Get-ItemProperty -Path $wallpapersKey -ErrorAction SilentlyContinue
    if ($wpProps.SlideshowSourceDirectoriesSet -ne 0 -or $wpProps.BackgroundType -ne 0) {
        Set-ItemProperty -Path $wallpapersKey -Name "SlideshowSourceDirectoriesSet" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $wallpapersKey -Name "BackgroundType" -Value 0 -Type DWord -Force
        Remove-ItemProperty -Path $wallpapersKey -Name "SlideshowDirectoryPath1" -ErrorAction SilentlyContinue
        Write-GuardLog "Verwaiste Windows-Diashow-Einstellung deaktiviert (BackgroundType=0)." "Disabled phantom Windows slideshow setting (BackgroundType=0)."
    }
}

# 2. Helper to discover current virtual desktops from Registry
function Get-LiveRegistryDesktops {
    $vdReg = Get-ItemProperty -Path $vdRootPath -ErrorAction SilentlyContinue
    $defaultWp = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -ErrorAction SilentlyContinue).WallPaper
    $list = @()
    if ($vdReg -and $vdReg.VirtualDesktopIDs) {
        $idsBytes = [byte[]]$vdReg.VirtualDesktopIDs
        $count = [int]($idsBytes.Length / 16)
        for ($i = 0; $i -lt $count; $i++) {
            $guidBytes = [byte[]]($idsBytes[($i*16)..($i*16+15)])
            $gStr = "{" + ([Guid]::new($guidBytes)).ToString().ToUpper() + "}"
            $sub = Get-ItemProperty -Path "$desktopsKeyPath\$gStr" -ErrorAction SilentlyContinue
            $dName = if ($sub -and $sub.Name) { $sub.Name } else { "Desktop $($i + 1)" }
            $dWall = if ($sub -and $sub.Wallpaper) { $sub.Wallpaper } else { $defaultWp }
            if ($dWall -and (Test-Path -LiteralPath $dWall)) {
                $dWall = (Get-Item -LiteralPath $dWall).FullName
            }
            $list += [PSCustomObject]@{
                Index     = ($i + 1)
                Guid      = $gStr
                Name      = $dName
                Wallpaper = $dWall
            }
        }
    }
    return $list
}

# 3. First-Run Auto-Discovery or Manual Save-Current-As-Default
if ((-not (Test-Path $configPath)) -or $SaveCurrentAsDefault) {
    $discovered = @(Get-LiveRegistryDesktops)
    $newConfig = [PSCustomObject]@{
        UpdatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
        Desktops  = $discovered
    }
    $jsonText = ConvertTo-Json -InputObject $newConfig -Depth 5
    [System.IO.File]::WriteAllText($configPath, $jsonText, [System.Text.Encoding]::UTF8)
    Write-GuardLog "Konfiguration für $($discovered.Count) virtuelle Desktops gespeichert ($configPath)." "Saved configuration for $($discovered.Count) virtual desktops ($configPath)."
    if (-not $ForceRestore) { exit 0 }
}

$config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Sync if user added or removed virtual desktops
$liveDesktops = @(Get-LiveRegistryDesktops)
if ($liveDesktops.Count -gt 0 -and ($liveDesktops.Count -ne $config.Desktops.Count)) {
    $existingByGuid = @{}
    foreach ($cd in $config.Desktops) { $existingByGuid[$cd.Guid.ToUpper()] = $cd }
    $merged = foreach ($ld in $liveDesktops) {
        if ($existingByGuid.ContainsKey($ld.Guid)) {
            $old = $existingByGuid[$ld.Guid]
            [PSCustomObject]@{
                Index     = $ld.Index
                Guid      = $ld.Guid
                Name      = if ($ld.Name) { $ld.Name } else { $old.Name }
                Wallpaper = if ($old.Wallpaper) { $old.Wallpaper } else { $ld.Wallpaper }
            }
        } else {
            $ld
        }
    }
    $config.Desktops = @($merged)
    $config.UpdatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
    [System.IO.File]::WriteAllText($configPath, (ConvertTo-Json -InputObject $config -Depth 5), [System.Text.Encoding]::UTF8)
}

$savedWallpapersByIndex = @{}
$liveWallpapers = @{}
$liveNames = @{}

foreach ($d in $config.Desktops) {
    $savedWallpapersByIndex[$d.Index] = $d.Wallpaper
    $subKey = "$desktopsKeyPath\$($d.Guid)"
    $p = Get-ItemProperty -Path $subKey -ErrorAction SilentlyContinue
    $liveWallpapers[$d.Index] = if ($p -and $p.Wallpaper) { $p.Wallpaper } else { "" }
    $liveNames[$d.Index] = if ($p -and $p.Name) { $p.Name } else { "" }
}

$configUpdated = $false
$healedCount = 0

foreach ($d in ($config.Desktops | Sort-Object Index)) {
    $idx = $d.Index
    $zeroIdx = $idx - 1
    $subKey = "$desktopsKeyPath\$($d.Guid)"
    if (-not (Test-Path $subKey)) { New-Item -Path $subKey -Force | Out-Null }

    $curName = $liveNames[$idx]
    $curWall = $liveWallpapers[$idx]

    if ($ForceRestore) {
        Set-ItemProperty -Path $subKey -Name "Name" -Value $d.Name -Type String -Force
        if ($d.Wallpaper) {
            Set-ItemProperty -Path $subKey -Name "Wallpaper" -Value $d.Wallpaper -Type String -Force
        }
        if (Test-Path $vdExe) {
            & $vdExe /Quiet "/GetDesktop:$zeroIdx" "/Name:$($d.Name)" "/Wallpaper:$($d.Wallpaper)" | Out-Null
        }
        $healedCount++
        continue
    }

    # Smart Name Check
    if ($curName -and ($curName -ne $d.Name)) {
        Write-GuardLog "Desktop $idx umbenannt ('$($d.Name)' -> '$curName') -> als neuer Standard übernommen." "Desktop $idx renamed ('$($d.Name)' -> '$curName') -> saved as new default."
        $d.Name = $curName
        $configUpdated = $true
    } elseif (-not $curName -and $d.Name) {
        Set-ItemProperty -Path $subKey -Name "Name" -Value $d.Name -Type String -Force
        if (Test-Path $vdExe) { & $vdExe /Quiet "/GetDesktop:$zeroIdx" "/Name:$($d.Name)" | Out-Null }
        $healedCount++
    }

    # Smart Wallpaper Check
    if ($d.Wallpaper -and ($curWall -ne $d.Wallpaper)) {
        if ($curWall -ieq $d.Wallpaper) {
            Set-ItemProperty -Path $subKey -Name "Wallpaper" -Value $d.Wallpaper -Type String -Force
            if (Test-Path $vdExe) { & $vdExe /Quiet "/GetDesktop:$zeroIdx" "/Wallpaper:$($d.Wallpaper)" | Out-Null }
            continue
        }

        $belongsToOtherSavedDesktop = $false
        foreach ($otherIdx in $savedWallpapersByIndex.Keys) {
            if ($otherIdx -ne $idx -and ($savedWallpapersByIndex[$otherIdx] -ieq $curWall)) {
                $belongsToOtherSavedDesktop = $true
                break
            }
        }

        $duplicateLiveCount = @($liveWallpapers.Values | Where-Object { $_ -ieq $curWall }).Count

        if ((-not $curWall) -or (-not (Test-Path -LiteralPath $curWall)) -or $belongsToOtherSavedDesktop -or ($duplicateLiveCount -ge 2)) {
            Set-ItemProperty -Path $subKey -Name "Wallpaper" -Value $d.Wallpaper -Type String -Force
            if (Test-Path $vdExe) {
                & $vdExe /Quiet "/GetDesktop:$zeroIdx" "/Wallpaper:$($d.Wallpaper)" | Out-Null
            }
            Write-GuardLog "Windows-Bug geheilt auf Desktop $idx ($($d.Name)): Zurückgesetzt auf '$($d.Wallpaper)'" "Healed Windows wallpaper reset on Desktop $idx ($($d.Name)): Restored '$($d.Wallpaper)'"
            $healedCount++
        } else {
            $normPath = (Get-Item -LiteralPath $curWall).FullName
            Write-GuardLog "Bewusster Wallpaper-Wechsel auf Desktop $idx ($($d.Name)) erkannt: '$normPath' gespeichert!" "Intentional wallpaper change detected on Desktop $idx ($($d.Name)): Saved '$normPath'!"
            $d.Wallpaper = $normPath
            Set-ItemProperty -Path $subKey -Name "Wallpaper" -Value $normPath -Type String -Force
            if (Test-Path $vdExe) {
                & $vdExe /Quiet "/GetDesktop:$zeroIdx" "/Wallpaper:$normPath" | Out-Null
            }
            $configUpdated = $true
        }
    }
}

if ($configUpdated) {
    $config.UpdatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
    [System.IO.File]::WriteAllText($configPath, (ConvertTo-Json -InputObject $config -Depth 5), [System.Text.Encoding]::UTF8)
}
