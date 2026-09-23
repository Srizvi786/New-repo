"""Pytest structure/content checks — no Godot binary needed."""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def _read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()

def test_required_files_exist():
    required = [
        "project.godot", "export_presets.cfg", "README.md",
        "main/Main.tscn", "main/Main.gd",
        "src/player/Player.gd", "src/player/CameraRig.gd",
        "src/input/TouchControls.gd", "src/input/VirtualJoystick.gd",
        "src/environment/TestArena.gd",
    ]
    for rel in required:
        assert os.path.isfile(os.path.join(ROOT, rel)), f"missing {rel}"

def test_project_godot_m1_settings():
    txt = _read("project.godot")
    assert "Dustline Strike" in txt
    assert "gl_compatibility" in txt
    assert "Main.tscn" in txt

def test_no_copied_ip():
    banned = ["PUBG", "Fortnite", "Free Fire", "Call of Duty", "Warzone"]
    for rel in ["README.md", "project.godot", "docs/architecture.md"]:
        txt = _read(rel)
        for b in banned:
            # allowed only in "do NOT copy" disclaimers
            if b in txt:
                assert "Do NOT copy" in txt or "No " in txt or "not " in txt.lower() or "Neither" in txt or "original" in txt.lower(), f"banned ref {b} in {rel}"

def test_player_has_core_mechanics():
    txt = _read("src/player/Player.gd")
    for kw in ["CharacterBody3D", "sprint", "crouch", "gravity", "jump", "get_state_dict"]:
        assert kw in txt, f"Player.gd missing {kw}"

def test_character_rig_m2():
    txt = _read("src/player/CharacterRig.gd")
    for m in ["set_state", "play_shoot", "play_reload", "play_hit",
              "play_death", "play_land", "set_lod", "get_weapon_mount"]:
        assert m in txt, f"CharacterRig.gd missing {m}"
    for marker in ["HeadMarker", "WeaponMount", "BackMount", "SidearmMount"]:
        assert marker in txt, f"CharacterRig.gd missing marker {marker}"
    for anim in ["crouch_walk", "sprint", "jump", "fall", "aim"]:
        assert anim in txt, f"CharacterRig.gd missing anim {anim}"
    ptxt = _read("src/player/Player.gd")
    assert "character_rig" in ptxt, "Player must delegate visuals to CharacterRig"
    assert "_build_placeholder_soldier" not in ptxt, "old inline soldier builder must be gone"
    assert os.path.isfile(os.path.join(ROOT, "tools/import_character.py"))

def test_touch_controls_mobile_ready():
    txt = _read("src/input/TouchControls.gd")
    for kw in ["joystick", "fire", "aim", "sensitivity"]:
        assert kw.lower() in txt.lower(), f"TouchControls missing {kw}"
    tscn = _read("src/input/TouchControls.tscn")
    assert "anchors_preset" in tscn or "anchor" in tscn

def test_weapon_data_driven():
    txt = _read("src/weapons/WeaponResource.gd")
    assert "class_name WeaponResource" in txt
    for f in ["pellets", "caliber", "eff_damage", "eff_spread", "attachments"]:
        assert f in txt, f"WeaponResource missing {f}"
    db = _read("src/weapons/WeaponDatabase.gd")
    for w in ['"ar"', '"smg"', '"shotgun"', '"sniper"', '"pistol"']:
        assert w in db.lower(), f"missing weapon {w}"
    wv = _read("src/weapons/WeaponView.gd")
    for f in ["try_fire", "start_reload", "hit_confirmed", "slot", "semi", "automatic", "fall"]:
        assert f in wv.lower(), f"WeaponView missing {f}"
    assert os.path.isfile(os.path.join(ROOT, "src/weapons/WeaponInventory.gd"))
    assert os.path.isfile(os.path.join(ROOT, "src/weapons/AttachmentData.gd"))

def test_combat_m4():
    h = _read("src/combat/Health.gd")
    for f in ["take_damage", "armor", "absorb", "died", "heal"]:
        assert f in h, f"Health.gd missing {f}"
    p = _read("src/player/Player.gd")
    for f in ["take_damage", "is_head_hit", "alive", "play_hit", "play_death"]:
        assert f in p, f"Player.gd missing combat {f}"
    hud = _read("src/ui/HUD.gd")
    assert "show_hitmarker" in hud and "Armor" in hud
    assert "Hitmark" in _read("src/ui/HUD.tscn")

def test_no_secrets_committed():    # NOTE: pattern uses dashed key header to avoid self-matching this file.
    pat = re.compile(r"ghp_[A-Za-z0-9]{10,}|BEGIN " + "PRIVATE KEY-----")
    for root, _dirs, files in os.walk(ROOT):
        if ".git" in root or ".godot" in root:
            continue
        for fn in files:
            if fn.endswith((".gd", ".md", ".cfg", ".yml", ".py")):
                txt = open(os.path.join(root, fn), encoding="utf-8", errors="ignore").read()
                assert not pat.search(txt), f"secret in {fn}"
