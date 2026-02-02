#!/bin/bash
# Vnefall build script

set -e

echo "Building Vnefall..."
odin build src -out:vnefall -debug

echo "Done. Run with: ./vnefall assets/scripts/demo_game.vnef"
