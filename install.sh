#!/bin/bash
# FLSUN_Timelapse installer for the FLSun T1 Pro.
# Run as the pi user from the cloned repo: ~/FLSUN_Timelapse/install.sh
# Safe to re-run, e.g. after a FLSun firmware update.

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENTS_DIR="${HOME}/moonraker/moonraker/components"
CONFIG_DIR="${HOME}/printer_data/config"
MOONRAKER_CONF="${CONFIG_DIR}/moonraker.conf"
PRINTER_CFG="${CONFIG_DIR}/printer.cfg"
FFMPEG="/usr/local/bin/ffmpeg"
MOONRAKER_URL="http://127.0.0.1:7125"

msg() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "run as the pi user, not root (sudo is used where needed)"
[ -d "$COMPONENTS_DIR" ] || die "Moonraker components not found at $COMPONENTS_DIR"
[ -f "$MOONRAKER_CONF" ] || die "$MOONRAKER_CONF not found"
[ -f "$PRINTER_CFG" ] || die "$PRINTER_CFG not found"
[ -x "$FFMPEG" ] || warn "$FFMPEG not found; frames will be saved but videos cannot be rendered"

# Restarting Klipper mid-print would kill the print.
state=$(curl -s -m 5 "${MOONRAKER_URL}/printer/objects/query?print_stats=state" \
    | sed -n 's/.*"state": *"\([a-z]*\)".*/\1/p')
case "$state" in
    printing|paused) die "a print is $state; run this again when the printer is idle" ;;
esac

# Clock, certificates and git https support; see prepare.sh.
"${REPO_DIR}/prepare.sh"

msg "Installing the boot service that sets the clock"
sudo install -m 755 "${REPO_DIR}/system/flsun-timesync" /usr/local/bin/flsun-timesync
sudo install -m 644 "${REPO_DIR}/system/flsun-timesync.service" /etc/systemd/system/flsun-timesync.service
sudo systemctl daemon-reload
sudo systemctl enable flsun-timesync.service > /dev/null 2>&1

msg "Linking the Moonraker component"
ln -sfn "${REPO_DIR}/component/timelapse.py" "${COMPONENTS_DIR}/timelapse.py"

msg "Linking the Klipper macros"
# printer.cfg already includes FLSun's empty timelapse.cfg stub; keep a copy.
if [ -f "${CONFIG_DIR}/timelapse.cfg" ] && [ ! -L "${CONFIG_DIR}/timelapse.cfg" ]; then
    mv "${CONFIG_DIR}/timelapse.cfg" "${CONFIG_DIR}/timelapse.cfg.flsun"
fi
ln -sfn "${REPO_DIR}/klipper_macro/timelapse.cfg" "${CONFIG_DIR}/timelapse.cfg"
if ! grep -q '^\[include timelapse\.cfg\]' "$PRINTER_CFG"; then
    cp "$PRINTER_CFG" "${PRINTER_CFG}.flsun_timelapse.bak"
    printf '\n[include timelapse.cfg]\n' >> "$PRINTER_CFG"
fi

msg "Adding the Moonraker settings"
if [ ! -f "${CONFIG_DIR}/flsun_timelapse.conf" ]; then
    cp "${REPO_DIR}/config/flsun_timelapse.conf" "${CONFIG_DIR}/flsun_timelapse.conf"
fi
if ! grep -q '^\[include flsun_timelapse\.conf\]' "$MOONRAKER_CONF"; then
    cp "$MOONRAKER_CONF" "${MOONRAKER_CONF}.flsun_timelapse.bak"
    printf '\n[include flsun_timelapse.conf]\n' >> "$MOONRAKER_CONF"
fi

msg "Restarting Moonraker and Klipper"
sudo systemctl restart moonraker
sudo systemctl restart klipper

msg "Done. Add TIMELAPSE_TAKE_FRAME to your slicer's timelapse G-code;"
msg "see ${REPO_DIR}/README.md."
