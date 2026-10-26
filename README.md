# Tailwind Admin Dashboard Droplet

A macOS AppleScript droplet that serves the bundled **Tailwind Admin Dashboard**
(`Contents/Resources/index.html`) over a local HTTP server and opens it in the
default browser. No drag-and-drop is required — just launch the app.

## Usage (macOS)

1. Launch `dashboard.app` (or `dashboard-signed.app` after signing).
2. A local Python HTTP server starts on the first free port beginning at `8080`.
3. Your default browser opens `http://localhost:<port>/index.html`.
4. Click **Stop Server** in the dialog to stop the server and quit.

Requirements: macOS with `python3` available on `PATH`.

## Linux desktop entry

`.desktop` runs `serve-drop.sh`, which can serve a dropped file/folder or prompt
for one when launched directly.

Requirements: `zenity`, `python3`, and `nc`.

```bash
./serve-drop.sh /path/to/site-or-file.html
```

## Code signing (macOS)

```bash
./sign.sh
```

The script stages a clean bundle (only `Contents`) so dev files such as `.git`
do not break signing, signs it with your `Developer ID Application` identity, and
writes the result to `../dashboard-signed.app`.

## Release signing (macOS)

#### Generate an [App-Specific Passwords](https://account.apple.com/account/manage)

#### ***!!! After !!!*** [release.yml](https://github.com/RandyMcMillan/dashboard.app/blob/main/.github/workflows/release.yml) succeeds in publishing a tagged release...

####  [https://github.com/RandyMcMillan/dashboard.app/releases](https://github.com/RandyMcMillan/dashboard.app/releases)

###### run:

```
./Release.sh --notarize --password ####-####-####-####
```

## Project layout

```text
dashboard.app/
├── Contents/
│   ├── MacOS/droplet          # AppleScript applet executable
│   ├── Resources/
│   │   ├── index.html         # Tailwind Admin Dashboard
│   │   └── Scripts/main.scpt  # Droplet logic
│   └── Info.plist
├── serve-drop.sh              # Linux/Unix helper
├── sign.sh                    # macOS signing helper
└── README.md
```
