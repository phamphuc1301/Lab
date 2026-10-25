# Habit Tracker

A small, clean desktop app for tracking daily habits. Built with Python and
[CustomTkinter](https://github.com/TomSchimansky/CustomTkinter), with light and dark themes.

## Features

- **Today screen**: check off or log each habit, move between days with `‹ ›` (or the arrow keys),
  and see an overall progress bar, current streak and the last 7 days for each habit.
- **Three ways to measure a habit**
  - **Yes / No**: done or not done (e.g. *Read before bed*)
  - **Count**: a daily goal with a unit and a +/− step (e.g. *8 glasses* of water)
  - **Duration**: minutes per day (e.g. *30 min* running, +5 per click)

  For count and duration habits, click the value to type an exact number.
- **Add / edit / delete / reorder** habits: use **+ New habit** (`Ctrl+N`) or a card's `⋯` menu.
- **Overview screen**: current and best streak, the last 30 days' completion rate, total days
  completed, and a 6-month heatmap for each habit.
- **Light / Dark / System** appearance, remembered between sessions.
- **Runs in the tray**: closing the window keeps the app running next to the clock. Click the tray
  icon to open the window, or right-click it to log today's habits without opening anything.
  Clicking a yes/no habit toggles it, and clicking a count or duration habit adds one step.
  Use **Quit** in that menu to exit completely. Turn this off with the **Keep running in tray** switch.
- **Start with Windows**: when this is on, the app starts quietly in the tray when you sign in. Turn it
  on in the installer or with the **Start with Windows** switch in the sidebar.
- **One instance**: opening the app again (Start menu, desktop icon) brings the running window to the front.

## Data

Everything is stored in a single readable JSON file:

```
%APPDATA%\HabitTracker\habits.json
```

Use **Open data folder** in the sidebar to find it. Saves are atomic: the app writes a temp file
and then swaps it in. If the file is ever unreadable, it is renamed to `habits.corrupt-<timestamp>.json`
instead of being overwritten. Set the `HABIT_TRACKER_DATA` environment variable to use a different file.
Uninstalling the app does **not** delete your data.

## Install (Windows)

Run `dist\HabitTrackerSetup-<version>.exe`. It installs per-user by default, so no admin rights
are needed, and adds a Start-menu entry. A desktop icon and starting with Windows are optional checkboxes.
Installing a newer version over an old one upgrades it in place and keeps your data.

> Windows 11 tucks new tray icons into the `^` overflow menu. To keep the icon always visible,
> drag it onto the taskbar, or turn it on in *Settings → Personalization → Taskbar → Other system tray icons*. A portable build is also produced at
`dist\HabitTracker-<version>-portable.zip`: unzip it and run `HabitTracker.exe`.

## Development

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -e ".[dev]"

python -m habit_tracker     # run the app
pytest                      # run tests
```

## Building the installer

```powershell
.\build.ps1                  # exe + portable zip + installer  ->  .\dist
.\build.ps1 -SkipInstaller   # exe + portable zip only
```

If PowerShell says *running scripts is disabled*, use
`powershell -ExecutionPolicy Bypass -File .\build.ps1` instead.

`build.ps1` creates its own `.venv-build`, bundles the app with PyInstaller (into `build\dist\HabitTracker`)
and then packages it with [Inno Setup 6](https://jrsoftware.org/isinfo.php)
(`winget install JRSoftware.InnoSetup`). To release a new version, change `__version__` in
`src/habit_tracker/__init__.py`.

## Project layout

```
habit-tracker/
├── src/habit_tracker/
│   ├── models.py      # Habit + measure types (check / count / duration)
│   ├── storage.py     # JSON persistence, streaks, completion rates
│   ├── app.py         # main window, Today + Overview screens
│   ├── widgets.py     # habit card, week dots, heatmap
│   ├── dialogs.py     # add / edit habit dialog
│   ├── theme.py       # colors & fonts (light, dark)
│   ├── tray.py        # system-tray icon and quick-log menu
│   ├── system.py      # start with Windows, single instance
│   └── assets/icon.ico
├── tests/             # pytest tests for models & storage
├── tools/make_icon.py # regenerates the app icon (Pillow)
├── packaging/         # PyInstaller entry point + Inno Setup script
└── build.ps1          # one-command Windows build
```
