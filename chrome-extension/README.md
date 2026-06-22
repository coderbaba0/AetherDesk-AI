# AetherDesk AI Chrome Extension

This folder contains a Chrome Extension MV3 client and an official Native Messaging Host.

The extension can:

* Save the current browser page into AetherDesk local data
* Log browser activity duration into `activity-data/`
* Run TrendRadar from selected/current topic
* Show live TrendRadar running/completed/failed status
* Notify and open the latest report when TrendRadar finishes
* Open the latest report or the reports folder from Chrome
* Save current page source and readable page text
* Capture a visible screenshot of a CSS selector such as `body`, `article`, `#main`, or `.content`
* Read local report/activity stats through the native host

## Install for Development

1. Open Chrome:

```text
chrome://extensions
```

2. Enable **Developer mode**.

3. Click **Load unpacked** and select:

```text
chrome-extension/
```

4. Copy the generated extension ID.

5. Build and register the native host with that ID:

```powershell
powershell -ExecutionPolicy Bypass -File .\chrome-extension\native-host\install-native-host.ps1 -ExtensionId YOUR_EXTENSION_ID
```

## Native Host Name

```text
com.aetherdesk.ai
```

## Data Written Locally

```text
activity-data/browser-activity-YYYY-MM-DD.jsonl
social-data/browser-saved-pages-YYYY-MM-DD.jsonl
social-data/browser-sources/YYYY-MM-DD/*.html
social-data/browser-sources/YYYY-MM-DD/*.json
screenshots/browser-captures/YYYY-MM-DD/*.png
screenshots/browser-captures/YYYY-MM-DD/*.json
reports/
```

## Selector Screenshot

Use the **Screenshot Selector** field with a CSS selector:

```text
body
article
#main
.content
```

Then click **Capture Selector**. The extension scrolls that element into view, captures the visible tab, crops the selected visible area, and saves it under `screenshots/browser-captures/`.

Current limitation: if the selected element is taller/wider than the visible viewport, only the visible area is captured. Full node stitching can be added later with a scroll-and-merge capture flow.

## Uninstall Native Host

```powershell
powershell -ExecutionPolicy Bypass -File .\chrome-extension\native-host\uninstall-native-host.ps1
```
