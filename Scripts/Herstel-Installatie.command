#!/bin/bash
cd "$(dirname "$0")" || exit 1
trap 'read -r -p "Druk op Enter om te sluiten."' EXIT
python3 patch_repair_import.py
