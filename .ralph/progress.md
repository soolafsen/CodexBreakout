# Ralph Progress

- 2026-03-29: Installed Godot 4.6.1, initialized the repo as a Godot project, and switched the plan from web-first to a native DX-Ball-style build.
- 2026-03-29: Implemented the main arcade loop in `scripts/game.gd` with multi-ball, lasers, catch, slow, wide, shrink, extra ball, nova bursts, explosive bricks, score, lives, and five candy-themed boards.
- 2026-03-29: Verified `godot --headless --path . --quit-after 1` and exported a Windows build plus zip via `scripts/export-windows.ps1`.
- 2026-03-30: Reworked brick-wall motion so levels use a bounded vertical sway instead of unbounded drift, with normal boards stopping higher and sinister boards pressing lower before retracting.
- 2026-03-30: Tuned the wall floor much lower, added calmer keyboard paddle control with a key sensitivity slider, and fixed the mouse handoff so keyboard play no longer snaps back to a parked cursor.
- 2026-03-30: Deferred idea for a future session: optional up/down paddle movement layered on top of the current wall sway, without regressing mouse directness or keyboard handoff behavior.
