#!/bin/bash
# Vnefall build script

set -e

echo "Building Vnefall..."
odin build src -out:vnefall -debug -collection:vneui=./vneui

echo "Done. Run with: ./vnefall demo/assets/scripts/demo_game.vnef"
