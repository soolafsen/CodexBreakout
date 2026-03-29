# Candy Breakout Bombast

Native Godot breakout built to channel DX-Ball 2 energy with louder candy colors, screen shake, particle bursts, multi-ball, lasers, explosive bricks, and falling power-ups.

## Play Now

1. Go to [Releases](https://github.com/soolafsen/CodexBreakout/releases/latest).
2. Download `CandyBreakoutBombast-win64.zip`.
3. Unzip it.
4. Double-click `CandyBreakoutBombast.exe`.

No Godot install is required for players.

## Controls

- `Mouse` or `Left/Right`: move paddle
- `Click` or `Space`: launch ball / continue / restart
- `F`: fire lasers when laser mode is active

## Build From Source

Open this folder in Godot and run `main.tscn`, or export a Windows build with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-windows.ps1
```

That script will:

- download Godot export templates if they are missing
- export `dist/CandyBreakoutBombast.exe`
- zip a ready-to-share package at `dist/CandyBreakoutBombast-win64.zip`

## Notes

- High score is saved locally in Godot `user://progress.cfg`.
- This first version is fully procedural: no external art pipeline is required.
- Ralph tracking lives in `.agents/tasks/prd-candy-breakout-bombast.json`.
