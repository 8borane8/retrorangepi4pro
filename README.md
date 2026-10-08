# Orange Pi 4 Pro image builder

Builds a bootable Linux image for the Orange Pi 4 Pro (Allwinner A733). The image includes the AIC8800 Wi-Fi and Bluetooth modules and the PowerVR GPU driver. The board has Gigabit Ethernet, USB 3, NVMe, and eMMC.

The default kernel branch `current` is Linux 6.6. `legacy` is Linux 5.15. Every image ships the matching kernel headers.

## Requirements

- Ubuntu 22.04
- sudo
- Several tens of gigabytes free for sources and the rootfs cache

## Build

```bash
sudo ./build.sh
```

The image is written to `output/images/`.

Override a setting for one run:

```bash
sudo ./build.sh PROFILE=server
```

Command line values win over `image.conf`.

## Configure

Edit [`image.conf`](image.conf) in this directory. The builder does not read a `userpatches` directory.

- `PROFILE`: `minimal`, `server`, or `desktop`
- `RELEASE`: `resolute`, `trixie`, `bookworm`, `jammy`, or `bullseye`
- `BRANCH`: `current` (6.6) or `legacy` (5.15)
- `HOSTNAME`, `USERNAME`, `PASSWORD`, `ROOT_PASSWORD`
- `TIMEZONE`, for example `UTC` or `Europe/Paris`
- `LOCALE`, for example `en_US.UTF-8` or `fr_FR.UTF-8`. Only this locale is generated. An Ubuntu desktop also installs that language's translation pack. English does not, because the programs are already in English.
- `KEYBOARD`, an XKB layout such as `us` or `fr`
- `EXTENSIONS`: kernel features from `extensions/`
- `APPS`: preconfigured software from `apps/`

Optional SSH public keys go in `authorized_keys` in this directory, one key per line. Server and desktop images install them for `USERNAME`.

## Profiles

- **minimal**: console, smallest package set, kernel headers. No SSH. No zram.
- **server**: console, OpenSSH, zram, kernel headers
- **desktop**: XFCE, OpenSSH, zram, and kernel headers. Debian bookworm and trixie also install Chromium. Bullseye installs Firefox ESR.

OpenSSH and zram are part of the server and desktop images. They are not extensions.

Ubuntu publishes Chromium only as a Snap. That package cannot finish installing while the image is built, so jammy and resolute desktops do not include a browser. Google Chrome has no arm64 package.

## Extensions

Kernel options. Set `EXTENSIONS` in `image.conf`. Each one rebuilds the kernel.

- **gamepads**: joystick, xpad, UHID, HIDRAW, and the Sony, Nintendo, and Steam HID drivers. Builds the xpadneo Bluetooth Xbox module.
- **wireguard**: TUN and WireGuard, `wireguard-tools`, and `/etc/wireguard/wg0.conf`. The interface stays disabled until you replace `REPLACE_ME` with a real private key.
- **usbip**: USB/IP host and VHCI, with `usbipd` enabled so a USB device can be shared on the LAN.

## Apps

Set `APPS` in `image.conf`.

- **docker**: `docker.io`, and the user is added to the `docker` group.
- **retroarch**: fullscreen, Ozone menu, udev gamepads, hotkeys, and folders under the home directory for ROMs, BIOS, saves, and savestates. Libretro cores are installed when the release archive has them. Select is the hotkey, Start quits, and the shoulder buttons save and load state. Escape, F2, and F4 do the same from a keyboard.
- **kodi**: `~/Videos` and `~/Music` as sources, a LAN playback cache, PulseAudio, and a web remote on port 8080 with no password. Kodi does not replace the XFCE session.
- **jellyfin**: official arm64 repository, service enabled, `/srv/media/videos` and `/srv/media/music`. Open port 8096 in a browser and attach those folders. That first visit is the one step Jellyfin still asks for.

## Flash

Write the `.img` file in `output/images/` to a microSD card with Balena Etcher, or with `dd` on Linux. Boot the Orange Pi 4 Pro from that card.

Log in with the username and password from `image.conf`. The defaults are `orangepi` / `orangepi`.
