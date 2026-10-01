# HEAT & CHAOS (Prototype)

2D top-down roguelike / bullet-heaven hybrid in Godot 4.7 (GDScript, Compatibility renderer, no external assets).
All art/audio is procedural: `_draw()` neon-on-rust visuals at 640x360 (pixel-upscaled), synthesized sfx.

## Play
Open the project in Godot 4.7 and press F5 (main scene: `scenes/ui/main_menu.tscn`).

| Action | Keys / Pad |
|---|---|
| Move | WASD / left stick |
| Aim, shoot | mouse, LMB / right stick, RT |
| Dash (i-frames) | Space / A |
| **Panic Vent** | Q or RMB / B |
| Use workshop bench | E / X (in the workshop room) |
| Presets (workshop room) | 1 / 2 / 3 |
| Pause | Esc / Start |
| Dev: the 4 monster builds | F1 Gravity Tornado, F2 Acid Minefield, F3 Ghost Sniper, F4 Kamikaze Toxin Carpet |
| Dev: spawn wave / next room | F5 / F7 |

Run: Start room -> Combat 1 -> Workshop -> Combat 2 -> Boss (VULCAN-IX). Doors lock during fights.

## Architecture
- `scripts/core` - autoloads `Game` (event bus + run state), `Settings`, `Save` (versioned JSON), `Router`, `Audio`; `run_controller.gd` (one run).
- `scripts/weapons` - `WeaponModule` Resources (`TriggerModule`, `TrajectoryModule`, `CatalystModule`), `WeaponLoadout`, `ModuleDB` (all balance values), `HeatSystem`, `InstabilitySystem`, `WeaponController`, pooled `Projectile`, `WorldEffect`.
- `scripts/feedback` - `JuiceController` (autoload `Juice`: hit-stop, directional shake, roll, zoom, distortion waves, chroma, flash, afterglow, pulse), `SquashSpring`/`SquashRig`, `ParticleField` (one node draws all particles; debris settles permanently), `PostFx` + `shaders/post_fx.gdshader`.
- `scripts/enemies` - `EnemyBase`, Stalker, Bulwark, Mortar-Mite, `VulcanBoss`.
- `scripts/rooms` - `Room` (geometry/hazards), `RoomManager` (waves, doors, `room_cleared`).
- `scripts/ui` - HUD, menus, workshop hub, panels (weapon bay, settings, codex, progression, run setup, pause/summary).

Signals on `Game`: `weapon_fired`, `heat_changed`, `misfire_triggered`, `misfire_warning`, `enemy_died`, `room_cleared`, `overheated`, `vent_used`, ...

Instability: module risks are *pre-rolled* - the next shot's misfire is shown above the player and in the HUD before you fire.
From 75% instability extra glitch misfires join the pool.

## Tests
```
godot --headless --path . res://tests/loadout_test.tscn   # 4 monster builds + rooms + boss (30 checks)
godot --headless --path . res://tests/flow_test.tscn      # menu -> run -> hub flow + real input path
godot --path . res://tests/capture.tscn -- mode=fight:tornado out=C:/tmp/x.png   # screenshots (needs a renderer)
```
Capture modes: `menu hub story setup codex settings progression hubbay bay pause summary workshop boss combat2 fight:<tornado|minefield|sniper|carpet>`.
(`tests/godot_path.txt` holds the local Godot console exe path used by `tests/run_test.sh`.)

## Known gaps
Acts 2-4, secret rooms, cursed chambers, music (only procedural drone + heart-beat), final art, enemy pooling (projectiles and particles are pooled).
