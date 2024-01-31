#!/usr/bin/bash

set -e
clear

STEAMCMD="steam -gamepadui -steamos3 -steampal -steamdeck -steamfs"

/usr/bin/gamescope --max-scale 2 \
        --adaptive-sync \
        -e \
        --xwayland-count 2 \
        -O *,eDP-1 \
        --default-touch-mode 4 \
        --hide-cursor-delay 3000 \
        --fade-out-duration 200 \
        --cursor-scale-height 720 \
        -R /run/user/1000/gamescope.byioejy/startup.socket \
        -T /run/user/1000/gamescope.byioejy/stats.pipe \
        -- $STEAMCMD
