#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

region="$(slurp)"
grim -g "$region" - | wl-copy --type image/png
