# 🛡️ Win11-Desktop-Guard

**Permanent Fix for Windows 11 Virtual Desktop Wallpaper Resets & Forgotten Window Positions after Reboot**  
**Dauerhafte Lösung gegen verstellte Hintergrundbilder & vergessene Fensterpositionen auf Virtuellen Desktops unter Windows 11**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows 11](https://img.shields.io/badge/Platform-Windows%2011%20(23H2%20%2F%2024H2%20%2F%2025H2)-0078D6.svg)](#)

*[🇩🇪 Deutsche Anleitung weiter unten](#-win11-desktop-guard-deutsch)*

---

## 🇬🇧 English Overview

### 😩 The Problem in Windows 11
If you organize your workflow across multiple **Virtual Desktops** (`Win + Tab`) in Windows 11, you have likely encountered two frustrating OS bugs:
1. **Virtual Desktop Wallpapers Randomly Reset:** After waking a monitor from sleep, restarting `explorer.exe`, or rebooting, Windows 11 frequently overwrites the wallpapers of several virtual desktops with the wallpaper of another desktop (often triggered by a phantom `SlideshowSourceDirectoriesSet` registry flag or `.webp`/`.gif` transcoding delays).
2. **Windows Forget Which Virtual Desktop You Moved Them To:** When you move open application windows (Word, Notion, File Explorer, Terminals, Chrome windows, etc.) to specific virtual desktops via `Win + Tab` or pin them to *"Show this window on all desktops"*, Windows 11 only keeps that assignment in volatile RAM (`dwm.exe` / `explorer.exe`). After a reboot, everything lands back on Desktop 1 or its old location.

### ✨ What `Win11-Desktop-Guard` Does
- **Smart Wallpaper-Lock & Auto-Heal:**
  - Automatically discovers your existing Virtual Desktops, names, and wallpapers on first run (**Zero-Config**).
  - Disables the hidden Windows 11 phantom slideshow bug in the Registry.
  - Synchronizes your wallpapers both in the Registry and directly in `explorer.exe`'s live COM state (`IVirtualDesktopManagerInternal`).
  - **Smart Auto-Detect:** Distinguishes between the Windows duplicate-overwrite bug (heals it automatically) and **intentional wallpaper or desktop name changes** made by you (learns and saves your new wallpaper automatically!).
- **Window-Desktop-Memory (Save & Restore across Reboots):**
  - Periodically snapshots all open windows across all virtual desktops (including **Desktop 1..N**, **"Show this window on all desktops"**, **"Show this app on all desktops"**, exact multi-monitor coordinates, and even open **File Explorer folder paths**).
  - Automatically moves your open windows back to their assigned Virtual Desktops after Windows logon (or with a single click).
- **Interactive HTML Dashboard:**
  - Generates a visual dashboard (`desktop_guard_dashboard.html`) displaying all your Virtual Desktops, wallpaper previews, and every window assigned to each desktop.

### 🚀 Quick Start (No Programming Required)
1. Download the latest release ZIP (**`Win11-Desktop-Guard-v1.0.0.zip`**) from [**Releases**](../../releases) and extract it to a permanent folder (e.g., `C:\Tools\Win11-Desktop-Guard`).
2. Double-click **`1_Install_Desktop_Guard.cmd`**.
   - This captures your current Virtual Desktops, wallpapers, and window positions, and registers two completely invisible background tasks in Windows Task Scheduler (`DesktopGuard_LogonRestore` & `DesktopGuard_PeriodicSync`).
3. **Optional 1-Click Tools:**
   - **`2_Save_Current_Layout_Now.cmd`** – Immediately saves all current wallpapers, desktop names, and window positions as the new default.
   - **`3_Restore_Layout_Now.cmd`** – Immediately restores all wallpapers and moves windows back to their saved virtual desktops.
   - **`4_Open_Dashboard.cmd`** – Opens your visual Virtual Desktop & Window Dashboard in your browser.
   - **`5_Uninstall_Desktop_Guard.cmd`** – Cleanly removes the scheduled background tasks at any time.

---

## 🇩🇪 Win11-Desktop-Guard (Deutsch)

### 😩 Das Problem unter Windows 11
Wer unter Windows 11 intensiv mit mehreren **Virtuellen Desktops** (`Win + Tab`) arbeitet, kennt zwei hartnäckige Windows-Bugs:
1. **Hintergrundbilder verstellen sich von selbst:** Nach einem Neustart oder wenn ein Monitor aus dem Standby aufwacht, überschreibt Windows 11 plötzlich die Hintergrundbilder mehrerer Desktops mit dem Bild eines anderen Desktops (oft ausgelöst durch ein verwaistes `SlideshowSourceDirectoriesSet`-Flag in der Registry oder Verzögerungen beim Laden von `.webp`/`.gif`-Bildern).
2. **Verschobene App-Fenster vergessen nach einem Neustart ihren Desktop:** Wenn man Fenster per `Win + Tab` (*Rechtsklick -> Verschieben nach*) auf verschiedene Desktops verteilt oder per *„Dieses Fenster auf allen Desktops anzeigen“* anheftet, speichert Windows 11 diese Zuordnung nur flüchtig im Arbeitsspeicher. Nach einem Neustart ist alles wieder am alten Platz.

### ✨ Was `Win11-Desktop-Guard` löst
- **Intelligenter Wallpaper-Schutz (Smart Auto-Detect):**
  - Erkennt beim ersten Start automatisch alle deine vorhandenen virtuellen Desktops, deren Namen und aktuelle Hintergrundbilder (**Zero-Config**).
  - Schaltet den versteckten Diashow-Überschreib-Bug in der Registry dauerhaft ab und synchronisiert deine Hintergrundbilder direkt über die interne Windows-11-COM-Schnittstelle.
  - **Darfst du deine Hintergrundbilder weiterhin selbst ändern? Ja!** Das Skript unterscheidet intelligent zwischen dem Windows-Duplikat-Bug (wird sofort repariert) und einem **bewussten Bildwechsel durch dich** (wird automatisch als neuer Standard übernommen und geschützt).
- **Fenster-Gedächtnis über Neustarts hinweg (`Window-Desktop-Memory`):**
  - Speichert automatisch alle 5 Minuten (sowie auf Knopfdruck) für alle offenen Fenster, auf welchem virtuellen Desktop sie liegen, ob sie *„Auf allen Desktops“* angeheftet sind, ihre exakten Monitor-Koordinaten sowie die **geöffneten Ordnerpfade von Datei-Explorer-Fenstern**.
  - Schiebt nach einem Neustart alle Fenster automatisch wieder auf ihren angestammten virtuellen Desktop zurück (und öffnet geschlossene Explorer-Ordner wieder).
- **Visuelles Live-Dashboard:**
  - Erstellt mit `4_Open_Dashboard.cmd` eine übersichtliche HTML-Ansicht aller deiner Desktops samt Hintergrundbild-Vorschau und Fensterliste.

### 🚀 Schnellstart (In 10 Sekunden eingerichtet)
1. Lade unter [**Releases**](../../releases) die Datei **`Win11-Desktop-Guard-v1.0.0.zip`** herunter und entpacke sie in einen festen Ordner (z. B. `C:\Tools\Win11-Desktop-Guard`).
2. Doppelklicke auf **`1_Install_Desktop_Guard.cmd`**.
   - Deine aktuellen Desktops, Hintergrundbilder und Fensterpositionen werden automatisch erfasst und zwei völlig unsichtbare Hintergrund-Aufgaben in der Windows-Aufgabenplanung eingerichtet (kein Aufblitzen von Konsolenfenstern).
3. **Weitere 1-Klick-Werkzeuge im Ordner:**
   - **`2_Save_Current_Layout_Now.cmd`** – Speichert den aktuellen Stand aller Hintergrundbilder und Fenster sofort als neuen Standard.
   - **`3_Restore_Layout_Now.cmd`** – Stellt alle Hintergrundbilder und Fensterpositionen sofort wieder her.
   - **`4_Open_Dashboard.cmd`** – Öffnet das visuelle Dashboard im Browser.
   - **`5_Uninstall_Desktop_Guard.cmd`** – Entfernt die Hintergrundaufgaben jederzeit rückstandslos.

---

## 🙏 Credits & License
- Released under the [**MIT License**](LICENSE).
- Uses [`VirtualDesktop`](https://github.com/MScholtes/VirtualDesktop) (`VirtualDesktop11-24H2.cs`, MIT License) by **Markus Scholtes** for native Windows 11 24H2/25H2 COM interop (`IVirtualDesktopManagerInternal`).
