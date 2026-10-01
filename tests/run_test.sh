#!/bin/bash
# usage: tests/run_test.sh [scene]   (default: loadout test) - prints errors + results only
EXE="$(cat tests/godot_path.txt | tr -d '\r')"
SCENE="${1:-res://tests/loadout_test.tscn}"
"$EXE" --headless --path . "$SCENE" 2>&1 | grep -v "^\s*$" | awk '!seen[$0]++' | head -${2:-70}
