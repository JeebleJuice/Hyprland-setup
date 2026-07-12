#!/usr/bin/env bash
set -euo pipefail

if command -v pypr >/dev/null 2>&1; then
    exec pypr --debug /tmp/pypr.log
fi

exit 0
