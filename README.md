# Win11-Desktop-Guard

PowerShell and C# utility for Windows 11 (23H2 / 24H2 / 25H2) to persist Virtual Desktop wallpapers and window-to-desktop assignments across reboots.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[Deutsche Beschreibung weiter unten](#beschreibung-deutsch)

---

## Overview

Windows 11 has two long-standing issues when working with multiple Virtual Desktops (`Win + Tab`):

1. **Per-desktop wallpapers resetting or duplicating:** After waking monitors from standby, restarting `explorer.exe`, or rebooting, Windows 11 frequently overwrites the wallpapers of several virtual desktops with the wallpaper from another desktop. This is typically triggered by a lingering `SlideshowSourceDirectoriesSet` value under `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers` or out-of-sync state between the `VirtualDesktops\Desktops\{GUID}` registry keys and `explorer.exe`'s in-memory `IVirtualDesktopManagerInternal` COM interface.
2. **Window-to-desktop assignments lost on reboot:** Moving application windows across virtual desktops (or pinning windows/apps via *"Show this window on all desktops"*) is only stored in volatile memory by `dwm.exe` / `explorer.exe`. After a reboot, reopened windows all land on the primary desktop.

`Win11-Desktop-Guard` addresses both issues using native Windows PowerShell scripts and a small C# Win32/COM helper (`DesktopGuard.dll` + Markus Scholtes's `VirtualDesktop11-24H2.cs`).

## How It Works

* **`restore_wallpapers.ps1`**
  Reads the `VirtualDesktopIDs` byte array from `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops`, disables the slideshow registry flag (`BackgroundType = 0`, `SlideshowSourceDirectoriesSet = 0`), and synchronizes desktop names and wallpaper paths both in the Registry and via `IVirtualDesktopManagerInternal` (`VirtualDesktop11.exe`).
  If a wallpaper changes on a single desktop to a new file path, the script updates `desktop_config.json` with the new path. If Windows overwrites a desktop's wallpaper with a duplicate from another desktop, the previous wallpaper from `desktop_config.json` is restored.

* **`save_window_layout.ps1`**
  Uses `DesktopGuard.dll` (`EnumWindows`, `GetWindowPlacement`, `IVirtualDesktopManager::GetWindowDesktopId`) and `Shell.Application` COM to record open top-level windows, their assigned Virtual Desktop GUID, pin state (`{BB64D5B7-4DE3-4AB2-A87C-DB7601AEA7DC}` for window pins, `{C2DDEA68-66F2-4CF9-8264-1BFD00FBBBAC}` for app pins), window coordinates, and open File Explorer directory paths to `window_layout.json`. Also writes a local HTML overview (`desktop_guard_dashboard.html`).

* **`restore_window_layout.ps1`**
  Runs after logon (or manually), restores the wallpaper configuration, optionally reopens saved File Explorer directories, matches running windows by process name, window class (`ClassName`), title, and coordinates, and moves them back to their recorded Virtual Desktop.

## Installation & Usage

No third-party runtimes are required (uses built-in Windows PowerShell 5.1 and `.NET Framework 4.x` `csc.exe` if binaries need to be rebuilt from `src/`).

1. Extract the repository or release archive to a permanent folder (for example `C:\Tools\Win11-Desktop-Guard`).
2. Run **`1_Install_Desktop_Guard.cmd`**.
   This saves your current Virtual Desktop configuration (`desktop_config.json`) and window positions (`window_layout.json`), and registers two user-level Scheduled Tasks (`DesktopGuard_LogonRestore` at logon and `DesktopGuard_PeriodicSync` every 5 minutes via `wscript.exe //B run_hidden.vbs`).

### Helper Batch Files

* `1_Install_Desktop_Guard.cmd` - Initial snapshot and Scheduled Task registration
* `2_Save_Current_Layout_Now.cmd` - Manually save current wallpapers, desktop names, and window positions
* `3_Restore_Layout_Now.cmd` - Manually restore wallpapers and move open windows to their saved desktops
* `4_Open_Dashboard.cmd` - Refresh and open `desktop_guard_dashboard.html`
* `5_Uninstall_Desktop_Guard.cmd` - Remove the `DesktopGuard_LogonRestore` and `DesktopGuard_PeriodicSync` scheduled tasks

## Repository Structure

```text
Win11-Desktop-Guard/
├── bin/
│   ├── DesktopGuard.dll          # Compiled Win32 / IVirtualDesktopManager helper
│   └── VirtualDesktop11.exe      # Compiled C# wrapper (MScholtes/VirtualDesktop)
├── src/
│   ├── DesktopGuard.cs           # C# source for window enumeration & desktop GUID lookup
│   └── VirtualDesktop11-24H2.cs  # C# source for Win11 24H2/25H2 COM interop
├── restore_wallpapers.ps1        # Wallpaper & desktop name synchronization
├── save_window_layout.ps1        # Window layout snapshot & HTML status page generator
├── restore_window_layout.ps1     # Window layout restore script
├── periodic_sync.ps1             # Wrapper called by the 5-minute scheduled task
├── install_desktop_guard.ps1     # Scheduled task installer
├── uninstall_desktop_guard.ps1   # Scheduled task uninstaller
└── run_hidden.vbs                # Runs PowerShell tasks without flashing a console window
```

---

## Beschreibung (Deutsch)

### Hintergrund

Beim Arbeiten mit mehreren virtuellen Desktops (`Win + Tab`) unter Windows 11 treten häufig zwei Probleme auf:

1. **Hintergrundbilder verstellen sich:** Nach einem Neustart, Explorer-Neustart oder dem Aufwachen eines Monitors aus dem Standby überschreibt Windows 11 oft die Hintergrundbilder einzelner virtueller Desktops mit dem Bild eines anderen Desktops. Ursache ist meist ein verwaistes `SlideshowSourceDirectoriesSet`-Flag in der Registry (`HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers`) oder eine Abweichung zwischen den Registry-Einträgen unter `VirtualDesktops\Desktops` und dem internen COM-Zustand von `explorer.exe`.
2. **Fenster-Zuordnungen gehen beim Neustart verloren:** Welche offenen Anwendungsfenster auf welchem virtuellen Desktop liegen (oder ob sie per *„Dieses Fenster auf allen Desktops anzeigen“* angeheftet sind), merkt sich Windows 11 nur im Arbeitsspeicher. Nach einem Neustart landen alle Fenster wieder auf Desktop 1.

### Funktionsweise

* **`restore_wallpapers.ps1`** liest beim ersten Start die vorhandenen virtuellen Desktops und deren zugewiesene Hintergrundbilder aus der Registry aus, legt `desktop_config.json` an, deaktiviert das Diashow-Flag und setzt Namen sowie Hintergrundbilder über die Registry und die COM-Schnittstelle (`VirtualDesktop11.exe`). Wenn man selbst ein neues Bild für einen einzelnen Desktop auswählt, übernimmt das Skript den neuen Pfad automatisch in die `desktop_config.json`. Wird ein Desktop hingegen durch den Windows-Bug mit dem Bild eines anderen Desktops überschrieben, stellt das Skript das ursprüngliche Bild wieder her.
* **`save_window_layout.ps1`** speichert alle offenen Anwendungsfenster inklusive Desktop-GUID, Anheft-Status (*Fenster/App auf allen Desktops*), Fensterkoordinaten und geöffneter Ordnerpfade im Datei-Explorer in `window_layout.json` und erzeugt eine lokale HTML-Übersicht (`desktop_guard_dashboard.html`).
* **`restore_window_layout.ps1`** stellt nach der Windows-Anmeldung (oder manuell per Skript) die Hintergrundbilder wieder her, öffnet bei Bedarf die gespeicherten Explorer-Ordner und verschiebt die laufenden Fenster anhand von Prozessname, Fensterklasse, Fenstertitel und Position wieder auf ihren jeweiligen virtuellen Desktop.

### Einrichtung

1. Repository oder Release-ZIP (`Win11-Desktop-Guard-v1.0.0.zip`) in einen festen Ordner entpacken (z. B. `C:\Tools\Win11-Desktop-Guard`).
2. **`1_Install_Desktop_Guard.cmd`** ausführen. Dadurch werden der aktuelle Zustand gespeichert und zwei Aufgaben in der Windows-Aufgabenplanung angelegt (`DesktopGuard_LogonRestore` bei Anmeldung sowie `DesktopGuard_PeriodicSync` alle 5 Minuten im Hintergrund über `wscript.exe`).
3. Über **`5_Uninstall_Desktop_Guard.cmd`** lassen sich beide Aufgaben jederzeit wieder aus der Aufgabenplanung entfernen.

---

## Credits & License

* Licensed under the [MIT License](LICENSE).
* Includes [`VirtualDesktop`](https://github.com/MScholtes/VirtualDesktop) (`VirtualDesktop11-24H2.cs`, MIT License) by Markus Scholtes for Windows 11 24H2/25H2 `IVirtualDesktopManagerInternal` COM interop.
