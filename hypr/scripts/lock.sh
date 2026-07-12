#!/bin/bash

if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

if command -v hyprlock >/dev/null 2>&1; then
    exec hyprlock
fi

loginctl lock-session
