# ORE//OPS — Star Citizen Mining Helper

A lightweight Windows mining companion for Star Citizen. It runs locally with
Windows PowerShell and WPF, so the first version has no installer or external
runtime dependency.

## Start the app

[Download Ops Helper.exe for Windows](https://github.com/planelander/ORE-HELPER/raw/refs/heads/main/dist/Ops%20Helper.exe)

Download and double-click the executable on Windows 10/11. No installer or
source folder is required. Use Star Citizen in borderless/windowed mode for the
overlay; F3 shows or hides it while detection continues.

Double-click **Ops Helper.exe** in the `dist` folder. This is a
portable, single-file release: it can be copied to another folder or Windows PC
without the rest of this project.

The launcher carries the branded ORE//OPS icon, prevents duplicate instances,
and hosts the interface in-process without opening a console or separate
PowerShell application.

On first launch, the executable creates its private working files under
`%LOCALAPPDATA%\OreOps\App`. Mining runs remain under `%LOCALAPPDATA%\OreOps`.
The command launcher remains available as a development fallback.

## Included in this MVP

The dashboard lists the four refined ores with the highest reported UEX selling
prices per SCU and a buying location offering each price. Its dated bundled
snapshot appears immediately; **REFRESH BUYER PRICES** updates it from UEX.
Tied buying locations show one alphabetically selected location. These are
community-reported prices, not guaranteed available demand.

- LIVE-build-labeled ore value index with search, sortable columns, and a visible verification date
- Rock breakability estimator for several mining configurations
- Raw-versus-refined cargo value calculator
- Local mining run log saved under `%LOCALAPPDATA%\OreOps`
- On-demand live-data snapshot download
- Editable mining data in `data/mining-data.json`

Only one downloaded location snapshot is retained. A validated new snapshot
replaces the old file, and stale legacy snapshot files are removed.

## Ship-fit presets (Windows)

In **Ship Fit**, configure your ship, mining heads, modules, active-head toggles,
and gadget. Enter a preset name and choose **SAVE / UPDATE**. Select a saved fit
and choose **LOAD** to restore it, or **DELETE** to remove it. Saving with the same
ship and name updates that preset. Presets persist in `%LOCALAPPDATA%\OreOps\ship-presets.json`.

## Refinery jobs (Windows)

In the Windows Run Log, select a refinery, ore, SCU, and remaining hours/minutes,
then select **SAVE RUN**. Each run keeps its own timer across restarts. The dashboard
shows **Job completed** when a timer expires and keeps the notification until the completed job is deleted.
The Run Log shows the countdown or completed status for each job. Older runs retain
their saved values and show **No timer**. Select any row and choose
**DELETE SELECTED JOB**, or choose **DELETE ALL COMPLETED** to clear finished jobs.
Bulk deletion keeps active jobs and older runs without timers; either can be deleted individually. The dashboard reflects only
Run Log timers. Timers use the duration entered from the game; they do not
sync with the game or send alerts while the app is closed.

## Live scan overlay (Windows)

Open Ops Helper and return to Star Citizen in borderless or windowed mode.
Detection starts automatically with the app and searches the central HUD for the
orange or yellow scan marker and its white RS number. No scan-area selection is required.
Press **F3** to show or hide the live overlay. Detection continues while hidden
and retries recognition after temporary errors. Capture runs while the game has focus.
A small orange-and-purple **ORE//OPS ON** badge appears at the bottom left while
enabled in game. The badge hides when disabled or when you switch apps.
F3 toggles the overlay only while Star Citizen has focus and ORE//OPS is running;
the overlay button is also available in the app. Holding F3 toggles once.
The readout appears near the top center of the game window,
matching the reference HUD. Recognition excludes distance labels and unrelated
HUD numbers and updates on the first readable marker (typically within a second).
The click-through overlay
shows only detected ore names, such as **Gold**, and remains hidden before a match.
Names remain visible for five seconds after the last recognized signature; a new
recognized ore updates the readout immediately.
The detector returns the nearest readable marker without waiting to scan every
cockpit label and reuses its OCR engine. Actual recognition latency depends on
HUD readability and the PC; screen OCR cannot guarantee a same-frame result.
Alternate matches remain visible because RS alone does not guarantee composition.
Ground signatures identify deposit size rather than a specific gem.

Recognition runs locally using Windows OCR and only captures the central HUD
while Star Citizen is foreground. Temporary images are deleted after recognition.
The overlay hides when you switch apps. Stop it from Signature Decoder; closing
ORE//OPS also stops capture. The search area follows the game window automatically.
Keep the marker near the center; unreadable, obscured, or multiple distinct
signatures hide the readout. Recognition errors appear inside the app only.
Windows needs an installed OCR language.
Exclusive fullscreen is unsupported. This feature is Windows-only.

In **07 Settings**, adjust **Overlay Lettering** in 10% steps from −50% to +50%.
The slider starts at 0% in the center for the default lettering size, with a live
preview. The active overlay updates immediately. Choose **SAVE SETTINGS** to
retain the size across restarts in `%LOCALAPPDATA%\OreOps\settings.json`.

## macOS

The cross-platform macOS source is under `mac`. It produces a Universal
`ORE-OPS.app` for Intel and Apple Silicon. The final merge must run on macOS
because Apple supplies the required `lipo` utility. A ready-to-run GitHub Actions
workflow is included at `.github/workflows/build-macos-universal.yml`.

## Accuracy

Market values are community estimates captured for the patch shown in the app.
Prices, availability, mining balance, refinery yield, modules, gadgets, and
server behavior can change. The rock assessment is a planning heuristic, not an
exact simulation or safety guarantee.

The bundled LIVE profile was checked on 2026-10-16 against RSI's Alpha 4.10.2
release notes (`4.10.2-LIVE.12881860`). Windows checks the official release listing
at startup and when downloading a snapshot; failed checks retain the last known
version and show a status message. The profile's mining-data date remains
2026-09-01 for the Alpha 4.10.0 estimates, which have not been reverified for 4.10.2.
The app keeps the official game build separate from community snapshot revisions.

## Data references

- RSI Industrial Gameplay Guide:
  https://robertsspaceindustries.com/en/comm-link/transmission/20050-Industrial-Gameplay-Guide
- RSI LIVE service status:
  https://status.robertsspaceindustries.com/
- UEX mining pricing:
  https://uexcorp.space/mining/pricing/
- UEX API documentation:
  https://uexcorp.space/api/documentation/id/commodities/
