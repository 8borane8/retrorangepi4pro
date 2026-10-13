# Orange Pi 4 Pro image builder

Builds a bootable Linux image for the Orange Pi 4 Pro (Allwinner A733). It includes the Wi-Fi and Bluetooth drivers (AIC8800). The board has Gigabit Ethernet, USB 3, NVMe and eMMC.

The default kernel is Linux 6.6 (`current`). `legacy` is Linux 5.15.

## Build

You need Ubuntu 22.04, `sudo`, and several tens of gigabytes of free disk space.

```bash
sudo ./build.sh
```

The image is written to `output/images/`.

To change a setting for one run:

```bash
sudo ./build.sh PROFILE=server
```

## Settings

Copy [`image.conf.example`](image.conf.example) to `image.conf` and edit it. `image.conf` stays local and is not committed. The first `sudo ./build.sh` creates it for you if it is missing. Values on the command line win over `image.conf`.

- `PROFILE`: `minimal`, `server` or `desktop`
- `RELEASE`: `resolute`, `trixie`, `bookworm`, `jammy` or `bullseye`
- `BRANCH`: `current` (6.6) or `legacy` (5.15)
- `HOSTNAME`, `USERNAME`, `PASSWORD`, `ROOT_PASSWORD`
- `TIMEZONE`, for example `Europe/Paris`
- `LOCALE`, for example `fr_FR.UTF-8`. Only this one is generated.
- `KEYBOARD`, for example `us` or `fr`
- `KERNEL_CONFIG`: extra kernel options (`CONFIG_NAME=y`, `=m` or `=n`). A new set of options builds a new kernel, which is then cached.

SSH keys: put public keys in a file named `authorized_keys` next to `build.sh`, one per line. They are installed for `USERNAME`. Password login keeps working.

## Profiles

- **minimal**: console only, the smallest image. The vendor kernel, no SSH, no zram.
- **server**: console, SSH, zram, kernel headers.
- **desktop**: server plus XFCE and Google Chrome.

Server and desktop also get:

- Kernel support for gamepads (Xbox, Sony, Nintendo, Steam), WireGuard, NFS, CIFS, and TCP BBR.
- `nvme-cli` and `smartmontools` to check disk health.
- `earlyoom`, which stops the biggest program before a full memory freezes the board.

There is no firewall. USB storage, exFAT and NTFS work on every profile.

## Desktop

- **Basics:** the desktop packages are installed without their optional extras, so the image adds what apps usually need. That means USB drive mounting, sound sharing, emoji fonts, H.264 in GStreamer, `jstest` for gamepads, and the libraries Qt AppImages need. A package missing on one release is skipped with a warning, and the build goes on.
- **Drawing:** the desktop is drawn by the CPU, with Mesa's software OpenGL, on the distribution's own Xorg. The display only redraws whole frames, so GPU drawing made the pointer flicker and the desktop lag. The window compositor is off (Settings > Window Manager Tweaks > Compositor turns it back on).
- **GPU apps:** programs that talk to the GPU directly, like Chrome (ANGLE on Vulkan) and Vulkan games or emulators, use it as usual.
- **Remote desktop:** `xrdp` is installed. Connect with any RDP client to the board's address on port 3389 and log in with the board's username and password.
- **No video player:** install one with `sudo apt install mpv` or `vlc`.

## Pins: GPIO, I2C, SPI

Every image has the `gpio`, `i2c` and `spi` groups, with rules that give them `/dev/gpiochip*`, `/dev/i2c-*` and `/dev/spidev*`. `USERNAME` is in all three groups, so no `sudo` is needed. Server and desktop add:

- `gpiod` (`gpioinfo`, `gpioget`, `gpioset`, `gpiomon`) and its Python module
- `i2c-tools` (`i2cdetect`, `i2cget`, `i2cset`) and `python3-smbus`
- `spi-tools` and `python3-spidev`
- Orange Pi's wiringOP: `gpio readall` shows the 40 pins, and C programs can link with `-lwiringPi`. It needs `sudo`.

I2C, SPI and UART are off until you enable them. Run `sudo orangepi-config`, go to **System**, then **Hardware**, tick the ones you want and reboot.

wiringOP is built while the image is made. If that fails, the image is still produced, without it, and the build prints a warning. `gpiod` and the Python modules keep working.

## GPU

The PowerVR GPU driver is on every console image, for compute. Desktop images get it on `resolute`, `trixie` and `bullseye`. `bookworm` and `jammy` desktops use software rendering.

The driver offers EGL with GLES, Vulkan and OpenCL, and no desktop OpenGL. Check it on the board with `vulkaninfo --summary` or `clinfo`. Orange Pi publishes the driver in one package that also carries its own Xorg. The image installs the package for the GPU libraries and then puts the distribution's Xorg back, so desktop OpenGL (GLX) works through Mesa on the CPU.

- The PowerVR libraries come first in the library path. A program that loads EGL gets the GPU's, which only offers GLES.
- GTK4 draws with Cairo, to stay off that path.
- Chrome starts with ANGLE on Vulkan. A Chrome update removes those flags.

## Video encoding

Every image has Allwinner's video engine and `demoVencoder` to test it. Server and desktop also have GStreamer with Allwinner's hardware encoder for H.264 and MJPEG:

```
gst-launch-1.0 filesrc location=in.mp4 ! decodebin ! videoconvert ! video/x-raw,format=NV12 ! omxh264videoenc ! h264parse ! mp4mux ! filesink location=out.mp4
```

## NPU

Every image has the Orange Pi NPU runtime and a test program. On the board, check `lsmod | grep vip`, then `cd /opt/vpm_run && sudo ./vpm_run sample.txt`.

## Flash

Write the `.img.xz` file from `output/images/` to a microSD card with Balena Etcher, or on Linux with `xzcat image.img.xz | sudo dd of=/dev/sdX bs=4M`. Then boot the board from that card.

Compression takes a few minutes and shows a progress bar. If it fails, the raw `.img` is kept. To skip it, set `COMPRESS_OUTPUTIMAGE="img"` in `image.conf`.

Log in with the username and password from `image.conf`. The defaults are `orangepi` / `orangepi`.

## Install on eMMC or NVMe

Boot from the microSD card, then run `sudo orangepi-config`, go to **System**, then **Install**. You can also run `sudo nand-sata-install`. It copies the running system and writes the bootloader.

- **Boot from eMMC - system on eMMC** is the main path. Remove the card after the power off.
- The SPI and UFS options depend on the hardware fitted and are not tested yet.
- The A733 U-Boot cannot boot from NVMe. For a system on NVMe, choose **Boot from eMMC - system on SATA, USB or NVMe**, or the SPI option.
