# HEAT & CHAOS (Prototype)

2D top-down roguelike / bullet-heaven hybrid in Godot 4.7 (GDScript, Compatibility renderer).
Procedural neon-on-rust visuals, synthesized audio, font: BoldPixels (`assets/fonts`). UI is 960x540 at 16px;
the world is rendered with camera zoom 1.5 (640x360 world units visible).

## Play
Open in Godot 4.7, F5 (main scene `scenes/ui/main_menu.tscn`).

| Action | Keys / Pad |
|---|---|
| Move | WASD / left stick |
| Aim, shoot | mouse, LMB / right stick, RT |
| Dash (i-frames) | Space / A |
| **Panic Vent** | Q or RMB / B |
| Workshop bench | E / X (presets 1/2/3 in the workshop room) |
| Pause | Esc / Start |
| Dev | F1-F4 monster builds, F6 cycle all 10 builds, F5 spawn wave, F7 next room, F8 boss room |

## The run
4 acts x 6 rooms (+ start room, + a secret cache behind a crack wall and a cursed chamber per act) = 33 rooms.
Rooms are Soul-Knight sized (up to 1200x680 world units), procedurally laid out per seed, with doors on all 4 sides.
The camera follows smoothly (look-ahead toward your aim) and is clamped so it never shows more than ~24px beyond the room.

| Act | Theme | Hazard | Boss |
|---|---|---|---|
| 1 | Steam Vaults | spikes, bumpers | VULCAN-IX (slam rings, heat ray, venting, magnetic pull) |
| 2 | Bio-Foundry | acid pools | THE SLIME-FUSED ENGINE (acid flood strips, mortars, ram, **mitosis** at 50%) |
| 3 | Magnet Spine | magnet fields | MAGNET WARDEN (**copies your trigger + trajectory** for its volleys) |
| 4 | Coremind | pulse emitters | THE PULSE (3 phases, can **override your weapon**; 4 endings) |

Enemies: Stalker, Bulwark, Mortar-Mite, Drone (swarm), Spit Turret, Foundry Slime (splits), Furnace Brute (elite), Magnet Hunter.
Endings (Shutdown / Containment / Fusion / Overload) unlock codex entries and alternative runners (Pyromaniac, Tinker, Warden).
Relics (secret rooms, elites, bosses): Cooling Fins, Overclock Fuse, Reactive Plating, Kinetic Boots, Scrap Magnet, Misfire Insurance, Vent Capacitor.
Cursed chambers: take one overloaded module, pay with a heart or +15 instability.

## Modules (28)
Triggers: Pulse Spitter, Buckshot Cluster, Beam Capacitor, Sniper Magazine, Giga-Cadence, Arc Emitter (chains), Flame Sprayer, Mine Layer, Seeker Swarm, Boomerang Saw.
Trajectories: Straight, Ricochet, Gravitational Curve, Orbital Magnet, Sinus Helix, Cyclone Curl, Split Prism, Hesitation Rail, Pendulum Rail.
Catalysts: Plain, Toxic, Shockwave, Implosion, Volcanic, Stasis Field, Splinter, Static, Twin Core.
Each module has its own misfire trait (shown BEFORE the shot). Heat also boosts damage (+40% at 100).

## Architecture
- `scripts/core` autoloads `Game` (bus + run state, relics, endings), `Settings`, `Save`, `Router`, `Audio`; `run_controller.gd`, `fonts.gd`.
- `scripts/weapons` Resource modules, `ModuleDB` (all balance values), Heat/Instability systems, `WeaponController`, pooled `Projectile` (shared by player + bosses), `WorldEffect`.
- `scripts/feedback` `Juice` (hit-stop, shake, roll, zoom, distortion, afterglow), squash rig, `ParticleField`, post shader (below the HUD so text stays crisp).
- `scripts/enemies` `EnemyBase`, 8 enemies, `BossBase` + 4 bosses. `scripts/rooms` `Room`, `RunPlan`, `WaveGen`, `RoomManager`.
- `scripts/ui` HUD (with minimap), menus, hub, panels.

## Tests
```
godot --headless --path . res://tests/loadout_test.tscn   # 67 checks: plan, rooms, camera, 10 builds, relics, secret, 4 bosses, ending
godot --headless --path . res://tests/flow_test.tscn      # menu -> run -> hub flow + real input path
godot --path . res://tests/capture.tscn -- mode=boss3 out=C:/tmp/x.png   # screenshots (needs a renderer)
```
Capture modes: `menu hub story setup codex settings progression hubbay bay pause summary workshop cursed act2 act3 act4 boss1..boss4 fight:<build>`.

## Known gaps
Final art/animation polish, real music (only procedural drone + heartbeat), enemy pooling (projectiles/particles are pooled), balance pass.
