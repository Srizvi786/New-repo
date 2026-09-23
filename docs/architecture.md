# Architecture — Dustline Strike

Godot 4.7, GDScript (typed), GL Compatibility renderer, Android-first.

## Principles

1. Working gameplay > stability > performance > controls > visuals > content > multiplayer > polish.
2. Modular, reusable, signals, Resources, state machines. No giant scripts, no hardcoded weapons in Player.
3. Offline-first, network-ready. No fake multiplayer UI.

## Scene / script map (M1)

```
Main (main/Main.tscn, Main.gd)
 ├─ WorldRoot (Node3D — arena instance goes here)
 ├─ MainMenu (Control)
 ├─ HUD (Control, hidden until play)
 ├─ TouchControls (Control, hidden on desktop unless touch)
 └─ PerfPanel (from PerformanceMonitor)
```

- `GameManager` (autoload): boot, state machine BOOT/MENU/LOADING/PLAYING/RESULTS, loads/unloads arena, owns match stub reference.
- `SaveSystem` (autoload): user://dustline_save.cfg — graphics, sensitivity, controls layout, audio. No secrets.
- `QualityManager` (autoload): LOW/MEDIUM/HIGH + auto-detect (OS model, RAM, cores, GLES3). Applies render scale, shadows, MSAA, fog density, view distance.
- `PerformanceMonitor` (autoload-ish Node, dev-only UI): FPS, frame ms, mem, draw calls, physics, object count.
- `InputManager` (autoload? No — Node in Main for M1, promoted later): owns InputMap actions, touch look vector, gyro stub, aim-assist stub.
- `Player` (CharacterBody3D): movement physics, crouch/capsule resize, camera rig ref, weapon view ref, health stub hook (full combat in M4). Owns NO meshes — visuals delegated to `CharacterRig`.
- `CharacterRig` (M2, `src/player/CharacterRig.gd`): articulated placeholder soldier, `set_state()` + `play_shoot/reload/hit/death/land/jump/switch` API, LOD0/1/2 with distance + quality scaling, attachment markers (Head/Weapon/Back/Sidearm). Real `.glb` implements the same API via `tools/import_character.py`.
- `CameraRig` (Node3D + SpringArm3D + Camera3D): third-person orbit + collision + recoil kick + first-person toggle (architecture ready, TP default for mobile).
- `TouchControls` + `VirtualJoystick`: left joystick, right look area, Fire/Aim/Jump/Crouch/Sprint/Reload buttons. Anchors + containers, no fixed coords. Customizable pos/size/sensitivity persisted.
- `WeaponResource` (Resource): damage, fire_rate, mag, reload, recoil, spread, range, headshot mult, auto. `WeaponDatabase`: 5 data rows (AR/SMG/Shotgun/Sniper/Pistol). `WeaponView`: hitscan placeholder + tracer + muzzle flash + recoil hooks (full system M3).
- `TestArena`: procedural PBR ground, scattered cover blocks, perimeter, sky/sun/fog. Collision-efficient boxes. LOD/instancing hooks documented for M6.
- `AudioManager`: Master/SFX/UI/Ambience buses, play_2d/3d hooks, gunshot/reload/footstep stubs.

## Client / server separation (M11-ready)

- `PLAYER STATE` (Player.gd exported vars + `get_state_dict()`), `MATCH STATE` (MatchManager stub), `WEAPON STATE` (WeaponResource instance + WeaponView), `WORLD STATE` (arena seed + loot table stub).
- All damage/zone decisions will be server-authoritative. Bots run local simulation (M7) using same interfaces.

## Milestones (all complete in v1.0.0)

M0 repo+arch • M1 player+camera+touch • M2 rig+LOD • M3 weapons • M4 combat •
M5 loot/inventory • M6 map • M7 bots • M8 match/results • M9 zone •
M10 optimization • M11 net baseline • M12 build • M13 polish.

## Validation

- `godot --headless --path . --import` must exit 0.
- `scripts/validate_project.gd` (headless GDScript check) + `pytest tests/` (structure + content checks).
- GitHub `validation.yml` runs both on every push.
