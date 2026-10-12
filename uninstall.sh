#!/bin/bash
# Removes FLSUN_Timelapse. Rendered videos in ~/printer_data/timelapse are kept.

set -e

COMPONENTS_DIR="${HOME}/moonraker/moonraker/components"
CONFIG_DIR="${HOME}/printer_data/config"
MOONRAKER_CONF="${CONFIG_DIR}/moonraker.conf"

msg() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

[ "$(id -u)" -ne 0 ] || { echo "run as the pi user, not root" >&2; exit 1; }

msg "Removing the Moonraker component"
[ -L "${COMPONENTS_DIR}/timelapse.py" ] && rm -f "${COMPONENTS_DIR}/timelapse.py"

msg "Restoring FLSun's timelapse.cfg"
if [ -L "${CONFIG_DIR}/timelapse.cfg" ]; then
    rm -f "${CONFIG_DIR}/timelapse.cfg"
    if [ -f "${CONFIG_DIR}/timelapse.cfg.flsun" ]; then
        mv "${CONFIG_DIR}/timelapse.cfg.flsun" "${CONFIG_DIR}/timelapse.cfg"
    else
        echo "#" > "${CONFIG_DIR}/timelapse.cfg"
    fi
fi

msg "Removing the Moonraker settings"
sed -i '/^\[include flsun_timelapse\.conf\]/d' "$MOONRAKER_CONF"
rm -f "${CONFIG_DIR}/flsun_timelapse.conf"
rm -rf "${HOME}/printer_data/timelapse_frames"

msg "Restarting Moonraker and Klipper"
sudo systemctl restart moonraker
sudo systemctl restart klipper

msg "Done. Videos are still in ~/printer_data/timelapse; delete ~/FLSUN_Timelapse to finish."
