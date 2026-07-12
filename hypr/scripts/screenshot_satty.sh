#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

shot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$shot_dir"

tmp_shot="$(mktemp --suffix=.png)"
trap 'rm -f "$tmp_shot"' EXIT

region="$(slurp)"
grim -g "$region" "$tmp_shot"

satty \
    --filename "$tmp_shot" \
    --output-filename "$shot_dir/%Y%m%d_%H%M%S_satty.png" \
    --actions-on-enter save-to-file \
    --copy-command wl-copy
