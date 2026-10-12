# Orange Pi 4 Pro image builder

Builds a bootable Linux image for the Orange Pi 4 Pro (Allwinner A733). The image includes the AIC8800 Wi-Fi and Bluetooth modules. The board has Gigabit Ethernet, USB 3, NVMe, and eMMC.

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

Copy [`image.conf.example`](image.conf.example) to `image.conf` and edit that file. `image.conf` is local and is not committed. The first `sudo ./build.sh` creates it from the example when it is missing. The builder does not read a `userpatches` directory.

- `PROFILE`: `minimal`, `server`, or `desktop`
- `RELEASE`: `resolute`, `trixie`, `bookworm`, `jammy`, or `bullseye`
- `BRANCH`: `current` (6.6) or `legacy` (5.15)
- `HOSTNAME`, `USERNAME`, `PASSWORD`, `ROOT_PASSWORD`
- `TIMEZONE`, for example `UTC` or `Europe/Paris`
- `LOCALE`, for example `en_US.UTF-8` or `fr_FR.UTF-8`. Only this locale is generated. An Ubuntu desktop also installs that language's translation pack. English does not, because the programs are already in English.
- `KEYBOARD`, an XKB layout such as `us` or `fr`
- `KERNEL_CONFIG`: extra kernel options, `CONFIG_NAME=y`, `=m`, or `=n`. Changing this rebuilds the kernel

Optional SSH public keys go in `authorized_keys` in this directory, one key per line. Server and desktop images install them for `USERNAME`.

## Profiles

- **minimal**: console, smallest package set, kernel headers. No SSH. No zram. The vendor kernel, unchanged.
- **server**: console, OpenSSH, zram, kernel headers
- **desktop**: XFCE, OpenSSH, zram, kernel headers, and Google Chrome

OpenSSH and zram are part of the server and desktop images. Those two images also enable gamepads (Xbox, Sony, Nintendo, Steam), WireGuard, NFS, and CIFS in the kernel. USB storage, exFAT, and NTFS are already in the vendor kernel, including on minimal.

## GPU

The PowerVR BXM-4-64 driver (kernel module, firmware, OpenCL, Vulkan, EGL, and GLES) is on every console image, for compute. Desktop images get it on resolute, trixie, and bullseye, the releases Orange Pi ships it on. Bookworm and jammy desktops use Mesa software rendering.

Orange Pi publishes the driver as one Debian 11 package that also replaces Xorg and its modesetting driver. On a desktop, `xserver-xorg-core` is held so an upgrade does not put the stock Xorg back. GTK4 draws with Cairo because its GL renderer crashes this driver. Chrome is started with ANGLE on Vulkan, as on the Orange Pi image. A Chrome update rewrites its launcher and drops those flags.

Check on the board with `vulkaninfo --summary` or `clinfo`. Both should name the PowerVR GPU.

## Flash

Write the `.img` file in `output/images/` to a microSD card with Balena Etcher, or with `dd` on Linux. Boot the Orange Pi 4 Pro from that card.

Log in with the username and password from `image.conf`. The defaults are `orangepi` / `orangepi`.
