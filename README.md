# Sound Labyrinth

A Godot 4.6 2D maze game with random levels, enemies, mouse-controlled flashlight fog, pickups, buffs, and web export support.

## Run

Open the project in Godot:

```powershell
.\open-godot.ps1
```

Or run Godot directly:

```powershell
godot --path . --editor
```

Press Play in the editor. The main scene is `res://scenes/level.tscn`.

## Controls

- `WASD` or arrow keys: move
- Mouse: aim flashlight
- `1`: sword attack

## Gameplay

- Reach the green exit to advance to the next randomly generated level.
- Avoid enemies.
- Pick up buffs:
  - `+`: heal
  - `S`: speed boost
  - `L`: stronger flashlight
  - `O`: shield

## Web Export

The project includes a Godot `Web` export preset.

In Godot:

```text
Project -> Export -> Web -> Export Project
```

The configured output path is:

```text
web/index.html
```

Serve the `web/` folder with a static server after export.

## Project Structure

```text
project.godot
scenes/level.tscn
scripts/level.gd
export_presets.cfg
open-godot.ps1
icon.svg
```
