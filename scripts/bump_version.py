#!/usr/bin/env python3
"""Bump version/name + version/code across all Android presets.

Usage: python3 scripts/bump_version.py 1.0.0 [code]
If code is omitted, current code + 1 is used.
"""
import re
import sys

PATH = "export_presets.cfg"

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    name, code = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None
    txt = open(PATH).read()
    codes = [int(c) for c in re.findall(r"version/code=(\d+)", txt)]
    new_code = int(code) if code else max(codes) + 1
    txt = re.sub(r'version/name="[^"]*"', f'version/name="{name}"', txt)
    txt = re.sub(r"version/code=\d+", f"version/code={new_code}", txt)
    open(PATH, "w").write(txt)
    print(f"version -> {name} (code {new_code})")
    return 0

if __name__ == "__main__":
    sys.exit(main())
