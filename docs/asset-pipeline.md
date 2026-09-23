# Asset pipeline — Dustline Strike

Goal: zero manual copy/paste, no copied IP, honest placeholders.

## Current state (M2)

Placeholder soldier is now an **articulated procedural rig** (`src/player/CharacterRig.gd`):
joints for hips/torso/head/arms/legs, 15-state pose system, LOD0/1/2, markers
(Head/Weapon/Back/Sidearm/Hands), hit-flash + death + reload/shoot overrides.
`Player` owns physics only; all visuals go through the rig interface, so a real
`.glb` swaps in without touching gameplay code. Swap contract + validator:
`tools/import_character.py assets/soldier.glb [--apply]`.

## Required assets (realistic pass, M2/M3/M6)

| Asset | Type | Purpose | Format | Poly/quality | Textures | Rig/anim | Import |
|---|---|---|---|---|---|---|---|
| Soldier body | char | player+bots | glTF 2.0 `.glb` | 15–25k tris LOD0, 8k LOD1, 3k LOD2 | 2k albedo+normal+rough+metal+AO, ETC2/ASTC on Android | Humanoid, 55–65 bones, root motion, attach: head/weapon/backpack/hand-LR | `import/lod` on, compress, loop anims, `root_motion` only on locomotion |
| Helmet/vest/pack/gloves/boots | gear | modular kit | glTF, same texel density | 2–6k each | same PBR set, camo tint via shader param | skin to body or rigid attach points | per-part `.tscn` with `BoneAttachment3D` |
| AR/SMG/Shotgun/Sniper/Pistol | weapon | view+world | glTF | 5–12k view, 3k world/LOD | 2k PBR, roughness metalness correct | muzzle + grip + mag + sight nodes; reload anim hooks | separate view/world scenes, cull small parts on LOW |
| Building kit/Town/Industrial | env | map M6 | glTF + tileable PNG | modular 1–4k per piece | 1k tileable albedo/normal/rough, trim sheets | none, snap pivots, collision boxes (not trimesh) | `physics/collision` = box, `visibility_range` + LOD |
| Tree/rock/grass | veg | map | glTF + billboard LOD | tree 2–5k→billboard, rock 1–3k, grass crossed quads | 1k, alpha_scissor on LOW | wind shader (vertex, cheap) | MultiMeshInstance3D, distance cull |
| Sky/lighting | env | mood | ProceduralSky + sun (no HDR texture on LOW) | — | — | — | WorldEnvironment preset per quality |

## AI 3D generation — honest status

**No AI 3D service is configured in this environment.** Nothing is auto-generated or faked.

If you want AI-generated soldier/weapons:
1. Tell me which service you have (e.g. Meshy, Tripo, Sloyd, CSM, local TripoSR/Zero123 — any is fine, all need accounts/keys).
2. I will add `tools/asset_fetch.py` that calls ONLY that real API (key via env/GitHub Secret, never committed), downloads `.glb`, validates poly/textures, and drops it into `assets/` with correct import presets.
3. Until then, M1 placeholder stays and M2 builds the swap pipeline (`CharacterRig` interface + LOD + attach points already in Player).

Do NOT commit downloaded commercial/ripped assets. Only original or properly licensed files.

## Import rules (Android)

- Mesh: compress vertices, LOD via `godot --headless --export` check, no Ngons.
- Texture: import as `Compress/ETC2_ASTC`, mipmaps on, anisotropy 2 on MEDIUM+, normal maps RGTC/ETC2.
- Audio: `.ogg` 44.1k mono for SFX, streaming for ambience.
- All imports must pass `godot --headless --path . --import` with zero errors.
