#!/bin/bash
set -u

if ! grep -qw disk /sys/power/state 2>/dev/null; then
    notify-send "Hibernate unavailable" "This kernel does not support disk sleep yet. Hibernate needs persistent swap and resume support."
    exit 1
fi

exec systemctl hibernate
