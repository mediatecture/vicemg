# VicEmergency Monitor

A small native macOS app that shows a continuous window listing nearby Victorian
emergency incidents (fire, flood, storm, hazmat, etc.), filtered by distance from
your location.

## Data source

Polls `https://emergency.vic.gov.au/public/events-geojson.json` — the GeoJSON feed
the live map at emergency.vic.gov.au itself runs on. It's public and needs no API
key, but it's **unofficial and reverse-engineered**: no documented SLA and no
guarantee the schema won't change, so treat this as ambient awareness and keep the
official VicEmergency app's push alerts as your safety-critical path.

The feed carries two kinds of entries:

- **Official warnings** (`feedType: warning`) with the genuine *Advice / Watch and
  Act / Emergency Warning* level, shown with that exact wording.
- **Incidents** (fires, tree downs, planned burns, BOM weather, etc.). These have no
  official severity field, so the app labels them **Active / Contained / Minor**
  from their status — that part is a heuristic.

Clicking a row opens that exact incident or warning on emergency.vic.gov.au
(`#!/warning/<id>/moreinfo` or `#!/incident/<id>`).

## Attribution and terms

Data is provided by the State of Victoria, Australia under a
[Creative Commons Attribution 3.0 Australia](https://creativecommons.org/licenses/by/3.0/au/)
licence, subject to Emergency Management Victoria's
[Emergency data notice](https://www.emv.vic.gov.au/responsibilities/victorias-warning-system/emergency-data).
The notice requires that the source is identified as *State of Victoria, Australia*,
that the notice is linked, and that apps showing warning data display the last date
and time an update was received. The app's footer does all three, and repeats the
notice's advice to use more than one source in an emergency. The licence excludes
Victorian Government logos and branding, none of which this app uses. The data is
provided "as is" with no warranty.

## Alerts

- **Red alert state** — the header and window border turn red whenever at least one
  item (matching your category filter) is inside your radius.
- **Notifications** — a native macOS notification banner fires when a *new* item
  enters your radius. Items already in range at launch don't trigger one. Each has a
  map thumbnail centred on the incident (with a blue dot for your location when it's
  in frame and a distance label), a badge icon for the emergency type (fire, tree,
  flood, wind, road, building, …) coloured by severity, and a matching emoji in the
  title. Fire-type items get a stronger treatment: a coloured tint, border and label
  strip, plus a matching badge. **Red** = active fire (or an official fire warning),
  **amber** = contained / controlled / safe fire, **yellow** = planned burn.
  If the map can't be fetched, the badge is shown on a plain background.
  "Send test notification" in Settings previews one for the nearest current item.
- **Alarm sound** — a synthesized two-tone siren plays alongside the notification.
  In Settings you can turn it off, restrict it to official warnings and active
  fires (default), or have it sound for every new nearby item. "Test alarm" plays it
  on demand. It plays through your Mac's currently selected output device.
- **Sound per emergency type** — Settings has a tick box for each type (fire, planned
  burn, tree down, flood, wind, storm / weather, road / rescue, building, other).
  Unticked types are completely silent: no siren and no notification chime, though
  the notification itself still appears. All types are on by default.

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
- **Sound** — siren on/off, whether it's limited to official warnings and active fires,
  and which emergency types make sound at all.
- **Categories** — filter by whichever categories the live feed currently contains
  (Fire, Tree Down, Planned Burn, Met, Advice, …).

All settings persist across launches (stored in `UserDefaults`).

## Project layout

```
Package.swift
Sources/VicEmergencyMonitor/
  App.swift              — app entry point
  AppSettings.swift       — persisted user settings
  LocationManager.swift   — CoreLocation wrapper
  IncidentFetcher.swift   — polls + decodes the feed
  IncidentModels.swift    — GeoJSON decoding, severity, detail-page URLs
  NearbyAlertManager.swift — detects newly-nearby items, triggers alerts
  NotificationManager.swift — native macOS notification banners
  NotificationImageRenderer.swift — map snapshot + type badge for the thumbnail
  AlarmPlayer.swift       — synthesized siren sound
  Views/
    ContentView.swift     — main window (list + filtering)
    SettingsView.swift    — settings sheet
    IncidentRow.swift     — one incident row
    WindowAccessor.swift  — "keep on top" window-level toggle
Resources/Info.plist       — app bundle metadata + location usage strings
Resources/AppIcon.icns     — app icon (generated by Scripts/make-icon.swift)
Scripts/make-icon.swift    — draws the icon; see the header comment for the regenerate command
build.sh                   — build + bundle + codesign
```
