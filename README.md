# FLSUN_Timelapse

Timelapse videos for the **FLSun T1 Pro**, viewable and downloadable from Mainsail and Fluidd.

FLSun's own timelapse depends on the FLSun phone app, which no longer works. This plugin replaces it with [moonraker-timelapse](https://github.com/mainsail-crew/moonraker-timelapse), the same timelapse that Zmod adds to Flashforge printers. It uses the T1 Pro's built-in camera stream and the ffmpeg that FLSun already ships.

## What it does

- Takes a camera snapshot every time the slicer emits `TIMELAPSE_TAKE_FRAME` (normally once per layer).
- Renders the frames into an MP4 when the print finishes.
- Adds the Timelapse panel and settings to Mainsail and Fluidd, where you can watch, download and delete videos.
- Updates from Mainsail's and Fluidd's update manager.

## Install

SSH into the printer as `pi` (the default password is `1`).

1. Prepare the system. FLSun's system image can't reach GitHub as shipped: the clock starts about a year and a half in the past, the certificate links are missing, and git's https support was removed. These commands fix all three:

   ```sh
   sudo ntpdate -u -b time.google.com
   curl -fsSL --cacert /etc/ssl/certs/ca-certificates.crt https://raw.githubusercontent.com/DIEHARDave/FLSUN_Timelapse/main/prepare.sh | bash
   ```

   Don't use `timedatectl set-ntp true`: on this image it stops the time service rather than starting it.

2. Download and install the plugin while the printer is idle:

   ```sh
   cd ~
   git clone https://github.com/DIEHARDave/FLSUN_Timelapse.git
   ~/FLSUN_Timelapse/install.sh
   ```

The installer restarts Moonraker and Klipper. It is safe to run again, for example after a FLSun firmware update that resets your config.

## Slicer setup

Tell the slicer to take a frame on each layer.

**OrcaSlicer:** Printer settings → Machine G-code → **Time lapse G-code**, enter:

```
TIMELAPSE_TAKE_FRAME
```

Then turn timelapse on in Mainsail or Fluidd (Settings → Timelapse → Enabled) before printing.

**PrusaSlicer / SuperSlicer:** add the same line to the "Before layer change G-code" field.

## Settings

Most settings are in Mainsail or Fluidd under Settings → Timelapse:

- **Park toolhead:** moves the head out of the way for each frame, for a cleaner video. It's off by default; with it off, frames are taken wherever the head is (the "stealth" mode).
- **Frame rate, video length and duplicate last frame:** these control how the finished video looks.

Rendering options live in `~/printer_data/config/flsun_timelapse.conf`. The installer creates this file once and never overwrites it. The defaults use fast encoding to suit the T1 Pro's slow processor. See [moonraker-timelapse's configuration guide](https://github.com/mainsail-crew/moonraker-timelapse/blob/main/docs/configuration.md) for every option.

Videos are saved in `~/printer_data/timelapse`.

## What the installer changes

| File | Change |
|---|---|
| `~/moonraker/moonraker/components/timelapse.py` | Link to `component/timelapse.py` |
| `~/printer_data/config/timelapse.cfg` | FLSun's empty stub is renamed to `timelapse.cfg.flsun` and replaced by a link to `klipper_macro/timelapse.cfg` (`printer.cfg` already includes it) |
| `~/printer_data/config/flsun_timelapse.conf` | New file: timelapse and update-manager settings |
| `~/printer_data/config/moonraker.conf` | Adds `[include flsun_timelapse.conf]` (a backup is saved first) |
| System clock | Sets it now, and adds `flsun-timesync.service` (`/usr/local/bin/flsun-timesync`), which sets it at every boot, saves it to `/etc/lasttime` and restarts ntpd. FLSun's `/etc/monitor` restores the date from that file at each boot but, because of a bug, never updates it, so without this fix the clock returns to the same old date after every boot |
| `/etc/ssl/certs` | Rebuilds the missing certificate links (`update-ca-certificates`) |
| git | Reinstalls Debian's git package (2.20.1-2+deb10u9) to restore the https support FLSun deleted |

## Uninstall

```sh
~/FLSUN_Timelapse/uninstall.sh
rm -rf ~/FLSUN_Timelapse
```

Rendered videos in `~/printer_data/timelapse` are kept. The system fixes (clock service, certificate links, git) stay, because they help the rest of the printer too.

## Changes from upstream

`component/timelapse.py` is moonraker-timelapse's file, unchanged (upstream commit `c7fff11`).

`klipper_macro/timelapse.cfg` has one change. FLSun overrides `SET_GCODE_OFFSET` with a macro that writes to disk on every call, so the park step calls the built-in command (`_SET_GCODE_OFFSET`) instead.

## Credits

- [moonraker-timelapse](https://github.com/mainsail-crew/moonraker-timelapse) by Christoph Frei, Alex Zellner and the mainsail-crew
- [ghzserg/timelapse](https://github.com/ghzserg/timelapse), the Zmod port that showed the way

Licensed under GPLv3, like moonraker-timelapse.
