#!/bin/bash

pkill -x waybar 2>/dev/null || true
sleep 0.1
waybar >/tmp/glass-waybar.log 2>&1 &
