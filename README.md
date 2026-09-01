# VicEmergency Monitor

A small native macOS app that shows a continuous window listing nearby Victorian
emergency incidents (fire, flood, storm, hazmat, etc.), filtered by distance from
your location.

## Data source

Polls `https://data.emergency.vic.gov.au/Show?pageId=getIncidentJSON` — the same
feed that powers the map on emergency.vic.gov.au. It's public and needs no API key,
but it's **unofficial and reverse-engineered**: no documented SLA, no guarantee the
schema won't change, and it does not expose the official Advice / Watch and Act /
Emergency Warning wording — the app derives an approximate severity (Active /
Contained / Minor) from category + status instead. Treat this as ambient awareness,
not a substitute for the official VicEmergency app/site/push alerts.

## Location

The app uses your Mac's built-in Location Services (CoreLocation) to detect where
you are — no manual coordinate entry needed. On first launch (or the first time you
enable "Use this Mac's current location" in Settings), macOS will prompt for
permission; if you miss it or deny it, open Settings in the app and click
**"Open Location Services Settings…"** to grant it under
*System Settings > Privacy & Security > Location Services*. You can also switch to
a manually-entered lat/long if you'd rather not grant location access.

## Building / running

```bash
./build.sh
open "VicEmergency Monitor.app"
```

`build.sh` compiles a release binary with Swift Package Manager, assembles it into
a proper `.app` bundle with `Resources/Info.plist`, and ad-hoc code-signs it (needed
for Location Services and Gatekeeper to treat it as a real app). Re-run `./build.sh`
after any code change; it rebuilds and re-signs in place.

## Run continuously / at login

The window stays open and refreshes on its own interval (default 1 minute,
configurable in Settings). To have it start automatically:

- **System Settings > General > Login Items** → add `VicEmergency Monitor.app`, or
- Drag `VicEmergency Monitor.app` into your Dock for one-click access.

Use the pin icon in the toolbar to keep the window floating above other apps.

## Settings

- **Location** — device location (via Location Services) or a manual lat/long.
- **Alert radius** — 5–200 km.
- **Refresh interval** — 30s / 1m / 2m / 5m.
- **Incident types** — filter by Fire, Flood, Storm, Accident/Rescue, Hazmat, Other.

All settings persist across launches (stored in `UserDefaults`).

## Project layout

```
Package.swift
Sources/VicEmergencyMonitor/
  App.swift              — app entry point
  AppSettings.swift       — persisted user settings
  LocationManager.swift   — CoreLocation wrapper
  IncidentFetcher.swift   — polls + decodes the feed
  IncidentModels.swift    — feed data model + severity heuristic
  Views/
    ContentView.swift     — main window (list + filtering)
    SettingsView.swift    — settings sheet
    IncidentRow.swift     — one incident row
    WindowAccessor.swift  — "keep on top" window-level toggle
Resources/Info.plist       — app bundle metadata + location usage strings
build.sh                   — build + bundle + codesign
```
