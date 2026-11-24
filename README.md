<p align="center"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/jesdr-logo-dark-600.png">
  <img src="assets/jesdr-logo-600.png" alt="jeSDR" width="420">
</picture></p>

# jeSDR

jeSDR is a new software suite for the sBitx HF transceiver. The radio works as
it always has, from its front-panel knobs, mic and key, and a touch-friendly
interface on the built-in screen, with dozens of new features and many
long-standing bugs fixed: FT8/FT4/FT2, JTTY, RTTY, PSK, CW decoder and macros,
FreeDV RADE V1, a voice keyer, DX cluster spots and a logbook built in, and a
JS8 mode that works with JS8Call on the Pi. The
same radio can also be operated from any browser on your network, and TCI,
HPSDR Protocol 1 and Hamlib connect your other programs.

This repository holds the **releases**: SD card images and installable
packages. jeSDR is closed source.

How to use it, with every screen and setting: the
**[jeSDR wiki](https://github.com/drexjj/jeSDR/wiki)**.

jeSDR is an independent project. It is built to run on sBitx hardware but is
not affiliated with or endorsed by the makers of the sBitx.

## Install

From the [latest release](https://github.com/drexjj/jeSDR/releases/latest):

**SD card image** (`jesdr-<version>-sdcard.img.xz`)

1. Write it to a microSD card (16 GB or more) with Raspberry Pi Imager
   ("Use custom") or balenaEtcher.
2. Put the card in the radio's Raspberry Pi and switch on. The first start
   takes a little longer (the card is expanded and the radio makes its own
   keys).
3. On the radio, open **jeSDR** from the desktop icon or the menu. From other
   devices, open `https://<radio>:8443/` (accept the certificate warning once
   per device; `http://<radio>:8080/` redirects there).

The image works on a Raspberry Pi 4 or Pi 5. jeSDR drives the radio's GPIO
and I2C through the kernel, so no GPIO library (WiringPi) is needed.

Writing a new image erases the card. Your settings, log and voice messages
are in `~/jeSDR/data` on the radio: copy that folder off first and back
afterwards, or use the update button instead (below), which keeps them.

**Package**, for a Raspberry Pi 4 or Pi 5 with Raspberry Pi OS 64-bit (Bookworm or later):

```console
sudo apt install ./jesdr_<version>_arm64.deb
```

## Updates

In the web interface: More → About → **Software updates** → **Check now**,
then **Install**. The radio also checks once a day and says when there is a
new version. Settings, log, calibration and voice messages are kept.

Updates are signed: a radio installs only packages whose manifest
(`latest.json` here, with `latest.json.sig`) carries the jeSDR release
signature and whose SHA-256 matches. If a new version does not start within
a minute, the radio puts the previous version back.

## Copyright and licenses

jeSDR is Copyright © 2026 J. Kujawa, W9JES. All rights reserved. It is built
on the sBitx software created by Ashhar Farhan, VU2ESE. The enhanced code is by
J. Kujawa, W9JES, with contributions from Jon W2JON, Alan N1QM, Lee W4WHL, Matt NM7D, Lars OZ7BX, Jeff KF7DYU, Mike KB2ML, Shawn K7IHZ, Jared KJ5DTK, Fabrizio F4VUK, Bob KD8CGH, Bob W7PUA, Phil KA9Q, Gerald K5SDR and Steve N3SB. jeSDR includes
software by others under their own licenses; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) (also in the web interface
under More → About). The SD card image also contains Raspberry Pi OS and its
packages, each under its own license; their sources are available from
Raspberry Pi and Debian.
