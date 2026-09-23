# Dustline Strike

**Dustline Strike** is an ORIGINAL realistic 3D battle-royale-style shooter for Android, built with **Godot 4.7 (GL Compatibility)**.

No PUBG / Free Fire / Fortnite / Call of Duty characters, maps, UI, sounds, logos, assets, or code are used. All art in this repo is procedural placeholder or original, designed to be replaced by licensed/original PBR assets via the pipeline in `docs/asset-pipeline.md`.

## Status

- Milestone 0 — repo + architecture: DONE
- Milestone 1 — player + camera + Android touch + test arena: DONE
- Milestone 2 — character rig pipeline (articulated placeholder, LOD, swap tool): DONE
- Milestones 3–13: planned (see `docs/architecture.md`)

## Quick start (desktop check)

Requires Godot **4.7.2-stable** (Linux arm64/x86_64, Windows, macOS all work — project is `GL Compatibility`).

```bash
# headless import / validate (CI does the same)
godot --headless --path . --import
godot --headless --path . --check-only --script res://scripts/validate_project.gd
python3 -m pytest tests/ -q
```

Open `main/Main.tscn` in the editor and press Play. WASD + mouse works on desktop; touch controls auto-show on Android / when `emulate_touch_from_mouse` fires.

## Controls

- Desktop: WASD move, Space jump, C crouch, Shift sprint, mouse look, LMB fire (placeholder), RMB aim, R reload placeholder
- Android: left virtual joystick = move, right-half drag = look, on-screen Fire / Aim / Jump / Crouch / Sprint / Reload buttons

## Project layout

```
project.godot
export_presets.cfg
main/Main.tscn            boot + world loader
src/core/                 GameManager, SaveSystem, QualityManager, PerformanceMonitor
src/player/               Player (CharacterBody3D) + CameraRig
src/input/                InputManager, VirtualJoystick, TouchControls
src/weapons/              WeaponResource (data-driven), WeaponDatabase, WeaponView
src/environment/          TestArena (procedural realistic-ish PBR test map)
src/ui/                   MainMenu, HUD
src/audio/                AudioManager (bus layout + hooks)
src/bots/  src/match/     stubs for M7/M8 (kept network-ready, offline-first)
docs/                     architecture, android-build, asset-pipeline, multiplayer, performance
.github/workflows/        validation.yml, android-build.yml
scripts/  tests/
```

## Android build

See `docs/android-build.md`. CI (`android-build.yml`) builds a debug APK/AAB with free GitHub runners + Godot export templates. Release signing needs your own keystore via GitHub Secrets — never committed.

## Visuals / performance

- PBR `StandardMaterial3D`, procedural sky + sun + fog, tonemapped `WorldEnvironment`
- Quality presets LOW / MEDIUM / HIGH + auto-detect (`QualityManager`)
- Target: 30 fps low-end, 40–60 mid, 60 high (never promised on all devices)
- Dev perf panel: FPS, frame ms, memory, draw calls, physics, objects (F3 or 3-finger tap)

## Asset honesty

Milestone 1 uses a **procedural placeholder soldier**, upgraded in M2 to an articulated
rig (`CharacterRig`: joints, 15-state poses, LOD0/1/2, attachment markers). It is NOT
claimed to be a final realistic character. Realistic human + weapons require either
an artist or an AI 3D service — see `docs/asset-pipeline.md` + `tools/import_character.py`
for the exact swap contract. No fake APIs are wired.

## License

Code in this repo is original. Replace placeholder art before commercial release and ensure all final assets are licensed/original.
