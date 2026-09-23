#!/usr/bin/env python3
"""Free, offline project validator. Fails on missing files, secrets, or bad references."""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

REQUIRED = [
    "project.godot",
    "icon.svg",
    "export_presets.cfg",
    "main/Main.tscn",
    "main/Main.gd",
    "src/core/GameManager.gd",
    "src/core/SaveSystem.gd",
    "src/core/QualityManager.gd",
    "src/core/PerformanceMonitor.gd",
    "src/player/Player.tscn",
    "src/player/Player.gd",
    "src/player/CameraRig.gd",
    "src/player/CharacterRig.gd",
    "src/combat/Health.gd",
    "src/items/ItemDatabase.gd",
    "src/items/Inventory.gd",
    "src/items/LootManager.gd",
    "src/items/LootPickup.gd",
    "tools/import_character.py",
    "src/input/InputManager.gd",
    "src/input/VirtualJoystick.gd",
    "src/input/TouchControls.tscn",
    "src/input/TouchControls.gd",
    "src/weapons/WeaponResource.gd",
    "src/weapons/WeaponDatabase.gd",
    "src/weapons/WeaponView.gd",
    "src/weapons/WeaponInventory.gd",
    "src/weapons/AttachmentData.gd",
    "src/weapons/TracerFX.gd",
    "src/bots/BotManager.gd",
    "src/bots/Bot.gd",
    "src/match/MatchManager.gd",
    "src/match/ZoneManager.gd",
    "src/environment/TestArena.tscn",
    "src/environment/TestArena.gd",
    "src/environment/BattleMap.tscn",
    "src/environment/BattleMap.gd",
    "src/ui/MainMenu.tscn",
    "src/ui/MainMenu.gd",
    "src/ui/HUD.tscn",
    "src/ui/HUD.gd",
    "src/ui/Results.tscn",
    "src/ui/Results.gd",
    "src/audio/AudioManager.gd",
    "docs/architecture.md",
    "docs/android-build.md",
    "docs/asset-pipeline.md",
    "docs/multiplayer.md",
    "docs/performance.md",
]

SECRET_PATTERNS = [
    (re.compile(r"ghp_[A-Za-z0-9]{10,}"), "github token"),
    (re.compile(r"github_pat_[A-Za-z0-9_]{10,}"), "github fine-grained token"),
    (re.compile(r"AIza[A-Za-z0-9_-]{10,}"), "google api key"),
    (re.compile(r"-----BEGIN (RSA )?PRIVATE KEY-----"), "private key"),
    (re.compile(r"keystore.*password\s*=\s*.+", re.I), "keystore password"),
]

def fail(msg):
    print(f"VALIDATE FAIL: {msg}")
    return False

def main():
    ok = True
    for rel in REQUIRED:
        p = os.path.join(ROOT, rel)
        if not os.path.isfile(p):
            ok = fail(f"missing {rel}") or False
    # secrets scan (text files only, skip .git)
    for dirpath, dirnames, filenames in os.walk(ROOT):
        if "/.git" in dirpath or "/.godot" in dirpath:
            continue
        dirnames[:] = [d for d in dirnames if d not in (".git", ".godot", "__pycache__")]
        for fn in filenames:
            if fn.endswith((".gd", ".md", ".cfg", ".tscn", ".yml", ".py", ".godot")):
                fp = os.path.join(dirpath, fn)
                try:
                    txt = open(fp, encoding="utf-8", errors="ignore").read()
                except OSError:
                    continue
                for rx, label in SECRET_PATTERNS:
                    if rx.search(txt):
                        ok = fail(f"possible {label} in {os.path.relpath(fp, ROOT)}") or False
    # project.godot sanity
    pg = open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read()
    for needle in ['config/name="Dustline Strike"', "4.7", "gl_compatibility", "SaveSystem", "QualityManager"]:
        if needle not in pg:
            ok = fail(f"project.godot missing '{needle}'") or False
    if "PUBG" in pg or "Fortnite" in pg:
        ok = fail("copied IP reference") or False
    print("VALIDATE OK" if ok else "VALIDATE FAILED")
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
