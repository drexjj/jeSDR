#!/bin/bash
# jeSDR installer for the sBitx (Raspberry Pi 4 or Pi 5, Raspberry Pi OS 64-bit).
#
#   curl -fsSL https://drexjj.github.io/jeSDR/install.sh | sudo bash
#
# Options (after "bash -s --" when piped, e.g. "| sudo bash -s -- --yes"):
#   --yes            answer yes to every question (no prompts)
#   --deb FILE       install this package instead of downloading the latest
#   --user NAME      run jeSDR as this user (default: the user who ran sudo)
#   --no-hw          do not touch the audio codec / I2C set-up
#   --no-js8call     do not offer to install JS8Call
#
# What it does:
#   1. checks this is a 64-bit Raspberry Pi OS (Bookworm or later) on a Pi 4 or Pi 5
#   2. installs the packages jeSDR needs and checks the GPIO (the user in the
#      gpio group, SPI off: the sBitx uses its pins)
#   3. sets up the sBitx audio codec (WM8731) and the I2C bus if they are not
#      set up already. Other programs get the radio's audio from jeSDR's own
#      PipeWire devices ("jeSDR Receive", "jeSDR Transmit"); the package
#      brings PipeWire on Raspberry Pi OS Lite.
#   4. downloads the latest jeSDR package, checks its SHA-256, installs it
#   5. downloads the country file (AD1C's Big CTY) for callsign lookups
#   6. offers to install JS8Call (JS8Call-improved's ARM64 AppImage, a
#      separate GPL program) for jeSDR's JS8 mode
#   7. offers to reboot when step 3 changed anything
#
# jeSDR is Copyright (c) 2026 J. Kujawa, W9JES.
set -eu

REPO="drexjj/jeSDR"
MANIFEST="https://raw.githubusercontent.com/$REPO/main/latest.json"

YES=0; DEB=""; RUN_USER=""; DO_HW=1; DO_JS8=1
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) YES=1 ;;
    --deb) DEB=${2:?--deb needs a file}; shift ;;
    --user) RUN_USER=${2:?--user needs a name}; shift ;;
    --no-hw) DO_HW=0 ;;
    --no-js8call) DO_JS8=0 ;;
    -h|--help) sed -n '2,25p' "$0" 2>/dev/null || true; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'; else B=''; G=''; Y=''; R=''; N=''; fi
step() { echo; echo "${B}==> $*${N}"; }
ok()   { echo "    ${G}ok${N}  $*"; }
warn() { echo "    ${Y}!!${N}  $*"; }
die()  { echo; echo "${R}error:${N} $*" >&2; exit 1; }

# Questions read the terminal even when the script itself comes from a pipe.
ask() {
  [ "$YES" = 1 ] && return 0
  local a=""
  if [ -r /dev/tty ]; then
    printf '    %s [Y/n] ' "$1" > /dev/tty
    read -r a < /dev/tty || a=""
  else
    return 0
  fi
  case "$a" in [nN]*) return 1 ;; *) return 0 ;; esac
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
REBOOT=0

echo "${B}jeSDR installer${N}"

# ---------------------------------------------------------------- 1. checks
step "Checking the system"
[ "$(id -u)" = 0 ] || die "run it with sudo:  curl -fsSL https://drexjj.github.io/jeSDR/install.sh | sudo bash"

ARCH=$(dpkg --print-architecture)
[ "$ARCH" = arm64 ] || die "jeSDR needs 64-bit Raspberry Pi OS (this system is $ARCH)."
ok "64-bit ($ARCH)"

. /etc/os-release
case "${VERSION_CODENAME:-}" in
  bookworm|trixie) ok "$PRETTY_NAME" ;;
  *) warn "$PRETTY_NAME: jeSDR is built for Bookworm; it may not work here"
     ask "Continue anyway?" || exit 1 ;;
esac

# Pi 4 family (Pi 4, Pi 400, CM4) or Pi 5 family (Pi 5, Pi 500, CM5). The
# Pi 5 needs Bookworm or later.
MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo unknown)
PI5=0
case "$MODEL" in
  *"Raspberry Pi 5"*|*"Compute Module 5"*) PI5=1; ok "$MODEL" ;;   # also the Pi 500
  *"Raspberry Pi 4"*|*"Compute Module 4"*) ok "$MODEL" ;;          # also the Pi 400
  *) warn "$MODEL: jeSDR is made for the sBitx's Raspberry Pi 4 or Pi 5"
     ask "Continue anyway?" || exit 1 ;;
esac
if [ "$PI5" = 1 ]; then
  case "${VERSION_CODENAME:-}" in
    bookworm|trixie) ;;
    *) die "a Raspberry Pi 5 needs Raspberry Pi OS Bookworm or later (this is ${PRETTY_NAME:-unknown})" ;;
  esac
fi

# the user jeSDR runs as: --user, an earlier install, the sudo user, else the
# first normal user
if [ -z "$RUN_USER" ] && [ -s /etc/jeSDR/user ]; then RUN_USER=$(cat /etc/jeSDR/user); fi
if [ -z "$RUN_USER" ] && [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then RUN_USER=$SUDO_USER; fi
if [ -z "$RUN_USER" ]; then RUN_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }'); fi
[ -n "$RUN_USER" ] && getent passwd "$RUN_USER" >/dev/null || die "no user to run jeSDR as; use --user NAME"
ok "jeSDR will run as user '$RUN_USER'"

# Another radio program holding the codec or GPIO stops jeSDR from starting.
OTHER=$(pgrep -a -x sbitx 2>/dev/null || true)
if [ -n "$OTHER" ]; then
  warn "the sBitx program is running:"
  echo "$OTHER" | sed 's/^/        /'
  warn "only one program can use the radio's audio codec and GPIO."
  if ask "Stop it now?"; then pkill -x sbitx || true; sleep 1; ok "stopped"; fi
  warn "also remove it from the desktop autostart, or it will take the radio again after a reboot."
fi

# ------------------------------------------------------- 2. needed packages
step "Installing the packages jeSDR needs"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q >/dev/null || warn "apt-get update failed; trying with the current package lists"
ASOUND=libasound2
# Trixie renamed it libasound2t64. Only a real candidate counts: on Bookworm
# the name can exist as a purely virtual package, which apt-cache show accepts
# but apt-get install refuses.
if apt-cache policy libasound2t64 2>/dev/null | grep -Eq 'Candidate: [^(]'; then ASOUND=libasound2t64; fi
apt-get install -y -q curl ca-certificates openssl python3 sudo alsa-utils unzip "$ASOUND" >/dev/null
ok "curl, openssl, python3, sudo, unzip, libasound (jeSDR drives the radio's codec through it)"

# PipeWire: jeSDR's audio devices for other programs ("jeSDR Receive",
# "jeSDR Transmit", ...). The library's development files too, so jeSDR can
# also be built from source on this Pi.
apt-get install -y -q pipewire wireplumber libpipewire-0.3-dev pkg-config >/dev/null \
  || die "could not install PipeWire (pipewire, wireplumber, libpipewire-0.3-dev)"
apt-get install -y -q pipewire-pulse pipewire-alsa >/dev/null 2>&1 \
  || warn "could not install pipewire-pulse / pipewire-alsa (PulseAudio and ALSA programs use them to reach jeSDR's devices)"
ok "PipeWire $(pkg-config --modversion libpipewire-0.3 2>/dev/null) and its development files (libpipewire-0.3-dev)"

# gpsd: for a USB GPS receiver (position and time in the field). -n reads
# the receiver from boot, so GPS time is there before anything asks.
apt-get install -y -q gpsd >/dev/null && ok "gpsd (for a USB GPS receiver)" || warn "could not install gpsd"
if [ -f /etc/default/gpsd ] && grep -q '^GPSD_OPTIONS=""' /etc/default/gpsd; then
  sed -i 's/^GPSD_OPTIONS=""/GPSD_OPTIONS="-n"/' /etc/default/gpsd
  grep -q '^USBAUTO=' /etc/default/gpsd || echo 'USBAUTO="true"' >> /etc/default/gpsd
  systemctl enable gpsd >/dev/null 2>&1 || true
  systemctl restart gpsd >/dev/null 2>&1 || true
fi

# GPIO: jeSDR drives the T/R relay, filters, keys and knobs through the
# kernel's GPIO device (/dev/gpiochip*); no GPIO library is needed. The
# user needs the gpio group.
if getent group gpio >/dev/null; then
  usermod -aG gpio "$RUN_USER" && ok "'$RUN_USER' is in the gpio group"
else
  warn "there is no gpio group; jeSDR may not be allowed to use the GPIO"
fi

# SPI0 shares GPIO7-11 with the sBitx's band filters and volume knob: with
# SPI on, the kernel holds those pins and jeSDR cannot use them.
GCFG=/boot/firmware/config.txt
[ -f "$GCFG" ] || GCFG=/boot/config.txt
if [ -f "$GCFG" ] && grep -Eq '^[[:space:]]*dtparam=spi=on' "$GCFG"; then
  warn "SPI is on (dtparam=spi=on in $GCFG); the sBitx needs those pins (GPIO7-11)"
  if ask "Turn SPI off?"; then
    cp "$GCFG" "$GCFG.jesdr-backup"
    sed -i -E 's/^([[:space:]]*)(dtparam=spi=on)/\1#\2   # jeSDR: the sBitx uses these pins/' "$GCFG"
    ok "SPI turned off (backup: $GCFG.jesdr-backup)"
    REBOOT=1
  else
    warn "the band filters and the volume knob will not work while SPI is on"
  fi
else
  ok "SPI is off (the sBitx uses its pins)"
fi

# --------------------------------------------------------- 3. sBitx audio
if [ "$DO_HW" = 1 ]; then
  step "Checking the sBitx audio set-up"
  CFG=/boot/firmware/config.txt
  [ -f "$CFG" ] || CFG=/boot/config.txt

  # WM8731 codec: the "audioinjectorpi" sound card
  if aplay -l 2>/dev/null | grep -q audioinjectorpi; then
    ok "audio codec (audioinjectorpi) is present"
  elif grep -Eq '^[[:space:]]*dtoverlay=audioinjector-wm8731-audio' "$CFG" 2>/dev/null; then
    ok "audio codec is set up in $CFG (active after a reboot)"
    REBOOT=1
  elif [ -f "$CFG" ]; then
    warn "the audio codec is not set up"
    if ask "Add 'dtoverlay=audioinjector-wm8731-audio' to $CFG?"; then
      cp "$CFG" "$CFG.jesdr-backup"
      printf '\n[all]\n# jeSDR: sBitx WM8731 audio codec\ndtoverlay=audioinjector-wm8731-audio\n' >> "$CFG"
      ok "added (backup: $CFG.jesdr-backup)"
      REBOOT=1
    fi
  else
    warn "no config.txt found; set up the audio codec yourself"
  fi

  # Kernel I2C for the Si5351, SWR bridge and INA260 (the zBitx's line).
  # The sBitx image's RTC overlay (i2c-rtc-gpio on GPIO 13/6) already makes
  # that bus, with the clock on it; a second overlay on the same pins hides
  # the clock, so it is not added there (and one added earlier is removed).
  I2CLINE='dtoverlay=i2c-gpio,bus=3,i2c_gpio_sda=13,i2c_gpio_scl=6'
  I2CRE='^[[:space:]]*dtoverlay=i2c-gpio,bus=3,i2c_gpio_sda=13,i2c_gpio_scl=6[[:space:]]*$'
  RTCRE='^[[:space:]]*dtoverlay=i2c-rtc-gpio,.*i2c_gpio_sda=13([^0-9]|$)'
  if grep -E "$RTCRE" "$CFG" 2>/dev/null | grep -Eq 'i2c_gpio_scl=6([^0-9]|$)'; then
    if grep -Eq "$I2CRE" "$CFG"; then
      cp "$CFG" "$CFG.jesdr-rtc-backup"
      sed -i -e '/^# jeSDR: the kernel drives the sBitx I2C bus/d' -e "/$I2CRE/d" "$CFG"
      ok "removed a second I2C overlay on the RTC's pins; it hid the clock (backup: $CFG.jesdr-rtc-backup)"
      REBOOT=1
    else
      ok "kernel I2C bus is set up (the RTC overlay provides it)"
    fi
    mkdir -p /var/lib/jeSDR && echo rtc > /var/lib/jeSDR/i2c-overlay
  elif [ -c /dev/i2c-3 ] && grep -Eq '^[[:space:]]*dtoverlay=i2c-gpio' "$CFG" 2>/dev/null; then
    ok "kernel I2C bus is set up (/dev/i2c-3)"
  elif grep -Eq '^[[:space:]]*dtoverlay=i2c-gpio' "$CFG" 2>/dev/null; then
    ok "kernel I2C bus is set up in $CFG (active after a reboot)"
    REBOOT=1
  elif [ -f "$CFG" ]; then
    # jeSDR needs it: it no longer bit-bangs these pins, and stops without the bus
    if ask "jeSDR needs the kernel's I2C bus for the radio. Add '$I2CLINE' to $CFG?"; then
      [ -f "$CFG.jesdr-backup" ] || cp "$CFG" "$CFG.jesdr-backup"
      printf '\n[all]\n# jeSDR: the kernel drives the sBitx I2C bus (Si5351, SWR bridge, INA260)\n%s\n' "$I2CLINE" >> "$CFG"
      mkdir -p /var/lib/jeSDR && echo added > /var/lib/jeSDR/i2c-overlay
      ok "added (backup: $CFG.jesdr-backup)"
      REBOOT=1
    else
      warn "jeSDR will not start without it: add '$I2CLINE' to $CFG yourself, then reboot"
    fi
  fi

  # Other programs' audio (WSJT-X, fldigi, JS8Call, SDROxide) goes through
  # jeSDR's PipeWire devices ("jeSDR Receive", "jeSDR Transmit", ...): no
  # ALSA loopback cards. The package installs PipeWire where it is missing
  # (Lite) and removes the loopback set-up older installers added.
  if command -v pipewire >/dev/null 2>&1; then
    ok "PipeWire is installed (other programs use jeSDR's PipeWire audio devices)"
  else
    ok "PipeWire comes with the jeSDR package (other programs use jeSDR's PipeWire audio devices)"
  fi
fi

# ------------------------------------------------------------ 4. jeSDR
step "Installing jeSDR"
if [ -n "$DEB" ]; then
  [ -f "$DEB" ] || die "no such file: $DEB"
  cp "$DEB" "$TMP/jesdr.deb"
  ok "using $DEB"
else
  curl -fsSL -o "$TMP/latest.json" "$MANIFEST" || die "could not download $MANIFEST"
  read -r VER URL SHA < <(python3 -c '
import json, sys
m = json.load(open(sys.argv[1]))
print(m["version"], m["url"], m["sha256"])' "$TMP/latest.json")
  echo "    downloading jeSDR $VER"
  curl -fL --progress-bar -o "$TMP/jesdr.deb" "$URL" || die "could not download $URL"
  GOT=$(sha256sum "$TMP/jesdr.deb" | cut -d' ' -f1)
  [ "$GOT" = "$SHA" ] || die "the download is damaged (SHA-256 does not match); try again"
  ok "jeSDR $VER downloaded and checked"
fi

mkdir -p /etc/jeSDR
echo "$RUN_USER" > /etc/jeSDR/user
chmod 755 "$TMP"; chmod 644 "$TMP/jesdr.deb"
SUDO_USER=$RUN_USER apt-get install -y -q "$TMP/jesdr.deb" >/dev/null
ok "installed $(dpkg-query -W -f='${Version}' jesdr) to /opt/jeSDR"

# ----------------------------------------------------- 5. country file
# AD1C's Big CTY file (www.country-files.com): callsign -> country, zones,
# continent. Free to download but not ours to ship, so it is fetched here, as
# the radio's user, into ~/jeSDR/data. Kept if it is less than 90 days old.
# A failed download does not stop the install.
step "Getting the country file (callsign lookups)"
CTY_HOME=$(getent passwd "$RUN_USER" | cut -d: -f6)
CTY="$CTY_HOME/jeSDR/data/bigcty.dat"
FETCH=/opt/jeSDR/tools/fetch_cty.sh
if [ -f "$CTY" ] && [ -n "$(find "$CTY" -mtime -90 2>/dev/null)" ]; then
  ok "the country file is up to date ($CTY)"
elif [ ! -f "$FETCH" ]; then
  warn "this jeSDR version has no $FETCH; skipping"
elif timeout 180 sudo -u "$RUN_USER" -H sh "$FETCH" > "$TMP/cty.log" 2>&1; then
  ok "$(grep '^Saved' "$TMP/cty.log" | sed 's/^Saved //' || echo "$CTY")"
else
  warn "could not download the country file; call lookups show no country until it is there:"
  sed 's/^/        /' "$TMP/cty.log" | tail -n 4
  warn "later, as $RUN_USER (not sudo):  sh $FETCH"
fi

# --------------------------------------------------------------- 6. JS8Call
# JS8Call (JS8Call-improved, GPL-3) is its own program: jeSDR's JS8 mode
# shows what it hears and sends through its TCP API. Its official ARM64
# AppImage goes in /opt/js8call; nothing of it is built into jeSDR.
JS8_DIR=/opt/js8call
JS8_REPO=https://github.com/JS8Call-improved/JS8Call-improved
JS8_FALLBACK=v3.0.3
if [ "$DO_JS8" = 1 ]; then
  step "JS8Call (optional, for the JS8 mode)"
  if [ "$(uname -m)" != aarch64 ]; then
    warn "JS8Call's AppImage is for 64-bit ARM; skipping"
  elif [ -x "$JS8_DIR/JS8Call.AppImage" ] && ! ask "JS8Call is installed ($(cat "$JS8_DIR/VERSION" 2>/dev/null || echo '?')). Check for a newer one?"; then
    ok "keeping $JS8_DIR/JS8Call.AppImage"
  elif [ ! -x "$JS8_DIR/JS8Call.AppImage" ] && ! ask "Install JS8Call (about 100 MB download) for jeSDR's JS8 mode?"; then
    ok "skipped (run this installer again to add it later)"
  else
    # the newest release: github.com/.../releases/latest redirects to .../tag/vX.Y.Z
    TAG=$(curl -fsSIL -o /dev/null -w '%{url_effective}' "$JS8_REPO/releases/latest" 2>/dev/null | sed -n 's#.*/tag/\(v[0-9][0-9.]*\)$#\1#p')
    [ -n "$TAG" ] || TAG=$JS8_FALLBACK
    if [ "$(cat "$JS8_DIR/VERSION" 2>/dev/null)" = "$TAG" ] && [ -x "$JS8_DIR/JS8Call.AppImage" ]; then
      ok "JS8Call $TAG is the newest"
    else
      JS8_URL="$JS8_REPO/releases/download/$TAG/JS8Call-$TAG-aarch64.AppImage"
      echo "    downloading JS8Call $TAG"
      if curl -fL --progress-bar -o "$TMP/js8call.AppImage" "$JS8_URL" &&
         [ "$(head -c 4 "$TMP/js8call.AppImage" | od -An -c | tr -d ' ')" = '177ELF' ]; then
        mkdir -p "$JS8_DIR"
        install -m 0755 "$TMP/js8call.AppImage" "$JS8_DIR/JS8Call-$TAG-aarch64.AppImage"
        ln -sfn "JS8Call-$TAG-aarch64.AppImage" "$JS8_DIR/JS8Call.AppImage"
        echo "$TAG" > "$JS8_DIR/VERSION"
        # older versions go
        find "$JS8_DIR" -maxdepth 1 -name 'JS8Call-v*-aarch64.AppImage' ! -name "JS8Call-$TAG-aarch64.AppImage" -delete 2>/dev/null || true
        ok "JS8Call $TAG in $JS8_DIR (from $JS8_REPO; its own licence, GPL-3)"
      else
        warn "could not download JS8Call from $JS8_URL"
        warn "jeSDR works without it; run this installer again later to add it"
      fi
    fi
    if [ -x "$JS8_DIR/JS8Call.AppImage" ]; then
      # AppImages need FUSE 2 (Trixie renamed it libfuse2t64)
      FUSE=libfuse2
      if apt-cache policy libfuse2t64 2>/dev/null | grep -Eq 'Candidate: [^(]'; then FUSE=libfuse2t64; fi
      if apt-get install -y -q "$FUSE" >/dev/null 2>&1; then ok "$FUSE (for AppImages)"
      else warn "could not install $FUSE: JS8Call will unpack itself each time it starts (slower)"; fi
      # the menu entry (Internet / Ham radio)
      cat > /usr/share/applications/js8call.desktop <<DESK
[Desktop Entry]
Type=Application
Name=JS8Call
Comment=JS8 keyboard-to-keyboard messaging (works with jeSDR's JS8 mode)
Exec=$JS8_DIR/JS8Call.AppImage
Terminal=false
Categories=Network;HamRadio;
DESK
      # A first set-up for jeSDR, only when JS8Call has none yet: the radio
      # through jeSDR's Hamlib server and the TCP API jeSDR reads. Audio
      # devices and PTT are chosen in JS8Call (Settings -> Radio / Audio).
      J_HOME=$(getent passwd "$RUN_USER" | cut -d: -f6)
      J_INI="$J_HOME/.config/JS8Call.ini"
      if [ -n "$J_HOME" ] && [ ! -e "$J_INI" ]; then
        J_CALL=$(grep -hE '^(#mycall|MYCALL)=' "$J_HOME/jeSDR/data/jesdr.ini" 2>/dev/null | tail -1 | cut -d= -f2 | tr -dc 'A-Za-z0-9/' | tr a-z A-Z)
        J_GRID=$(grep -hE '^(#mygrid|MYGRID)=' "$J_HOME/jeSDR/data/jesdr.ini" 2>/dev/null | tail -1 | cut -d= -f2 | tr -dc 'A-Za-z0-9')
        sudo -u "$RUN_USER" mkdir -p "$J_HOME/.config"
        {
          echo "[Configuration]"
          [ -n "$J_CALL" ] && echo "MyCall=$J_CALL"
          [ -n "$J_GRID" ] && echo "MyGrid=$J_GRID"
          echo "Rig=Hamlib NET rigctl"
          echo "CATNetworkPort=127.0.0.1:4532"
          echo "TCPEnabled=true"
          echo "AcceptTCPRequests=true"
          echo "TCPServerPort=2442"
          echo "TCPMaxConnections=2"
        } > "$TMP/JS8Call.ini"
        install -o "$RUN_USER" -g "$(id -gn "$RUN_USER")" -m 0644 "$TMP/JS8Call.ini" "$J_INI"
        ok "set JS8Call up for jeSDR ($J_INI): rig Hamlib NET rigctl, TCP API on"
        warn "in JS8Call still choose the audio devices jeSDR Receive (input) and jeSDR Transmit (output), and PTT method CAT"
      elif [ -e "$J_INI" ]; then
        ok "JS8Call's own settings are kept ($J_INI)"
      fi
    fi
  fi
fi

# ------------------------------------------------------------ 7. finish
HOSTN=$(hostname)
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
step "Done"
echo "    The program:   /opt/jeSDR   (service: jesdr, user: $RUN_USER)"
echo "    Your data:     $(getent passwd "$RUN_USER" | cut -d: -f6)/jeSDR/data"
echo
echo "    On this radio: the jeSDR icon on the desktop or in the menu (Internet)."
echo "    From other devices:"
echo "      https://$HOSTN.local:8443/${IP:+     or  https://$IP:8443/}"
echo "    The browser warns about the radio's own certificate the first time;"
echo "    choose Advanced -> Proceed once on each device."
echo
echo "    Check on it:   systemctl status jesdr      journalctl -u jesdr -f"
echo "    Country file:  sh $FETCH   (as $RUN_USER, a few times a year)"

if [ "$PI5" = 1 ]; then
  echo
  warn "Raspberry Pi 5: it draws more current than a Pi 4. Use a 5 V supply that can"
  warn "give 5 A, or the Pi slows down and jeSDR shows a PI POWER warning."
fi

if [ "$REBOOT" = 1 ]; then
  echo
  warn "the audio set-up changed: the radio must restart before jeSDR can use it."
  if ask "Reboot now?"; then
    echo "    rebooting..."
    sleep 2
    systemctl reboot
  else
    echo "    Reboot when ready:  sudo reboot"
  fi
fi
