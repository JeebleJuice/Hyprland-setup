#!/usr/bin/env bash
set -euo pipefail

if command -v hyprsunset >/dev/null 2>&1; then
    exec hyprsunset
fi

exit 0
