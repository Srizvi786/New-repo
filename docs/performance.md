# Performance — Dustline Strike

Android has priority over looks. Compatibility renderer, budgeted effects.

## Quality presets (`QualityManager`)

| Setting | LOW | MEDIUM | HIGH |
|---|---|---|---|
| render scale (viewport scale_3d) | 0.7 | 0.85 | 1.0 |
| shadow | off / 512 | on 1024, distance 40m | on 2048, distance 80m |
| MSAA 3D | off | 2x | 2x |
| fog/volumetric feel | cheap fog only | fog + light shafts fake | fog + denser + sky AO |
| view distance (camera far) | 150m | 250m | 400m |
| veg density | 0.25 | 0.6 | 1.0 |
| debris/particles | off | reduced | full |

Auto-detect: `OS.get_model_name()` + `OS.get_processor_count()` + `OS.get_memory_info()` heuristic; persisted override in `SaveSystem`.

## Budgets (M1 arena, mid-range target)

- Draw calls < 80, tris < 250k, physics bodies < 60, AI 0 (M7 adds ≤12 cheap bots).
- No per-frame allocations in `_physics_process`; object pooling stubbed for projectiles/tracers (M3).
- Textures procedural in M1 (zero VRAM from imports); real assets must use ETC2/ASTC + mipmaps.

## Dev panel (`PerformanceMonitor`)

F3 toggles (or 3-finger tap 0.5s): FPS, frame ms avg, mem MB, draw calls (`RenderingServer.get_render_info`), physics ms, objects, player count, ping stub.

## M10 measures (implemented)

- **Dynamic resolution**: per-60-frame FPS average; <25 fps for 3 windows steps
  render scale down (1.0→0.85→0.7→0.6), >55 fps for 5 windows steps up.
  Toggle: `QualityManager.dynamic_res`.
- **Tracer pool**: bot/event tracers reuse 32 pooled nodes (`TracerFX`), cleared
  per match; player gun keeps its own capped pool (24).
- **Loot culling**: pickups skip idle animation beyond 40 m (0.5 s recheck).
- **Shared materials**: map reuses ~13 materials; vegetation is 4 MultiMesh draws.
- **Bots**: staggered 0.25 s thinking, ≤11, corpses freed after 20 s.
- **Character LOD**: 0 (<25 m), 1 (<60 m), 2 (capsule); LOW preset forces ≥1 past 15 m.

## Profiling

- `godot --headless` cannot profile GPU; use `adb logcat | grep Godot` + in-game panel on device.
- Before M10 sign-off: test on at least one low-end (2–3 GB RAM, Mali/Adreno 600-series) at LOW.
