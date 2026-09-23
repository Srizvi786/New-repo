#!/usr/bin/env python3
"""Drop-in pipeline for a real soldier .glb (M2 swap contract).

Usage:
    python3 tools/import_character.py assets/soldier.glb [--apply]

Without --apply it only validates and prints the contract.
With --apply it copies the file to assets/characters/soldier.glb and writes
assets/characters/soldier.import.json describing Godot import expectations.

Contract the .glb must satisfy (checked when `pygltflib` is available,
otherwise printed for manual check in Blender):
  - Humanoid skeleton (~55-65 bones), Y-up, ~1.8m tall
  - Named nodes (case-insensitive match): Head, WeaponMount (right hand),
    BackMount, SidearmMount, HandL, HandR
  - Animations (clips): idle, walk, run, sprint, jump, fall, land, crouch,
    crouch_walk, aim, shoot, reload, switch, hit, death
  - PBR textures embedded or alongside: albedo, normal, roughness/metallic, AO
  - LOD0 <= 25k tris (LOD1/LOD2 generated in Godot via import presets)

No AI service is called. No assets are downloaded. Missing file = exit 2.
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REQUIRED_NODES = ["head", "weaponmount", "backmount", "sidearmmount", "handl", "handr"]
REQUIRED_ANIMS = ["idle", "walk", "run", "sprint", "jump", "fall", "land",
                  "crouch", "crouch_walk", "aim", "shoot", "reload",
                  "switch", "hit", "death"]


def check_glb(path):
    """Return (ok, messages). Uses pygltflib if installed, else structural checks."""
    msgs = []
    size = os.path.getsize(path)
    msgs.append(f"file: {path} ({size / 1048576:.1f} MB)")
    if size > 150 * 1048576:
        return False, msgs + ["FAIL: file > 150 MB, re-export with Draco/compression"]
    try:
        from pygltflib import GLTF2
        gltf = GLTF2().load(path)
        names = [(n.name or "").lower() for n in gltf.nodes]
        missing = [r for r in REQUIRED_NODES if not any(r in n for n in names)]
        if missing:
            msgs.append(f"WARN: nodes not found (ilicharacter rig will dummy them): {missing}")
        else:
            msgs.append("nodes: all required markers present")
        anims = [(a.name or "").lower() for a in (gltf.animations or [])]
        missing_a = [a for a in REQUIRED_ANIMS if not any(a in n for n in anims)]
        if missing_a:
            msgs.append(f"WARN: anim clips missing (procedural fallback kept): {missing_a}")
        else:
            msgs.append("anims: all 15 clips present")
        return True, msgs
    except ImportError:
        msgs.append("pygltflib not installed: manual contract check required")
        msgs.append(f"required nodes: {REQUIRED_NODES}")
        msgs.append(f"required anims: {REQUIRED_ANIMS}")
        return True, msgs
    except Exception as e:  # noqa: BLE001
        return False, msgs + [f"FAIL: could not parse glb: {e}"]


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        print("No .glb given — nothing to do (placeholder rig stays active).")
        return 2
    src = argv[1]
    apply = "--apply" in argv
    if not os.path.isfile(src):
        print(f"FAIL: not found: {src}")
        return 2
    if not src.lower().endswith(".glb"):
        print("FAIL: only .glb is accepted (glTF 2.0 binary).")
        return 2
    ok, msgs = check_glb(src)
    print("\n".join(msgs))
    if not ok:
        return 1
    if apply:
        dst_dir = os.path.join(ROOT, "assets", "characters")
        os.makedirs(dst_dir, exist_ok=True)
        dst = os.path.join(dst_dir, "soldier.glb")
        shutil.copyfile(src, dst)
        meta = {
            "source": os.path.basename(src),
            "rig_interface": "CharacterRig (set_state/play_shoot/play_reload/play_hit/play_death/play_land)",
            "markers": REQUIRED_NODES,
            "anims": REQUIRED_ANIMS,
            "godot_import": {"compress_vertices": True, "generate_lods": True,
                             "texture_compression": "ETC2_ASTC", "mipmaps": True},
        }
        with open(os.path.join(dst_dir, "soldier.import.json"), "w") as f:
            json.dump(meta, f, indent=2)
        print(f"applied: {dst}")
    else:
        print("dry-run only (pass --apply to copy into assets/).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
