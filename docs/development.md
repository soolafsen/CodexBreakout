# Development

This page is for people changing the game or rebuilding the Windows package. Players should use the download link on the front page instead.

## Prerequisites

- Windows
- [Godot 4.6+](https://godotengine.org/download/windows/)
- PowerShell

The repo does not require a separate programming framework beyond Godot for normal development.

## Run From Source

1. Open the project folder in Godot.
2. Run `main.tscn`.

You can also verify the project from the command line:

```powershell
godot --headless --path . --quit-after 1
```

## Create A Player Build

Use the export script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-windows.ps1
```

What it does:

- downloads Godot export templates if they are missing
- exports `dist/CandyBreakoutBombast.exe`
- creates `dist/CandyBreakoutBombast-win64.zip`

## Project Files

- `scripts/game.gd`: main gameplay loop, rendering, pickups, scoring, and level flow
- `main.tscn`: root scene
- `project.godot`: project config
- `export_presets.cfg`: Windows export preset
- `.agents/tasks/prd-candy-breakout-bombast.json`: Ralph-style task tracking

## Controls

- `Mouse` or `Left/Right`: move paddle
- `Click` or `Space`: launch ball / continue / restart
- `F`: fire lasers when laser mode is active

## Notes

- High score is stored in Godot `user://progress.cfg`.
- `dist/` and `.godot/` are build or generated output and are not committed as source.
