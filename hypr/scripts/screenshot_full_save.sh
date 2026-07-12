#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

shot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$shot_dir"

outfile="$shot_dir/Screenshot_$(date +%Y%m%d_%H%M%S).png"
grim "$outfile"
