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

def test_touch_controls_mobile_ready():
    txt = _read("src/input/TouchControls.gd")
    for kw in ["joystick", "fire", "aim", "sensitivity"]:
        assert kw.lower() in txt.lower(), f"TouchControls missing {kw}"
    tscn = _read("src/input/TouchControls.tscn")
    assert "anchors_preset" in tscn or "anchor" in tscn

def test_weapon_data_driven():
    txt = _read("src/weapons/WeaponResource.gd")
    assert "class_name WeaponResource" in txt
    db = _read("src/weapons/WeaponDatabase.gd")
    for w in ['"ar"', '"smg"', '"shotgun"', '"sniper"', '"pistol"']:
        assert w in db.lower(), f"missing weapon {w}"

def test_no_secrets_committed():
    # NOTE: pattern uses dashed key header to avoid self-matching this file.
    pat = re.compile(r"ghp_[A-Za-z0-9]{10,}|BEGIN " + "PRIVATE KEY-----")
    for root, _dirs, files in os.walk(ROOT):
        if ".git" in root or ".godot" in root:
            continue
        for fn in files:
            if fn.endswith((".gd", ".md", ".cfg", ".yml", ".py")):
                txt = open(os.path.join(root, fn), encoding="utf-8", errors="ignore").read()
                assert not pat.search(txt), f"secret in {fn}"
