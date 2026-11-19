#!/bin/bash
# jeSDR installer for the sBitx (Raspberry Pi 4 or Pi 5, Raspberry Pi OS 64-bit).
#
#   curl -fsSL https://drexjj.github.io/jeSDR/install.sh | sudo bash
#
# Options (after "bash -s --" when piped, e.g. "| sudo bash -s -- --yes"):
#   --yes            answer yes to every question (no prompts)
#   --deb FILE       install this package instead of downloading the latest
#   --user NAME      run jeSDR as this user (default: the user who ran sudo)
#   --no-hw          do not touch the audio codec / loopback set-up
#
# What it does:
#   1. checks this is a 64-bit Raspberry Pi OS (Bookworm or later) on a Pi 4 or Pi 5
#   2. installs the packages jeSDR needs, and WiringPi if it is missing (on a
#      Pi 5 it must be WiringPi 3.0 or newer; an older one is upgraded)
#   3. sets up the sBitx audio codec (WM8731) and three ALSA loopback cards
#      if they are not set up already
#   4. downloads the latest jeSDR package, checks its SHA-256, installs it
#   5. downloads the country file (AD1C's Big CTY) for callsign lookups
#   6. offers to reboot when step 3 changed anything
#
# jeSDR is Copyright (c) 2026 J. Kujawa, W9JES.
set -eu

REPO="drexjj/jeSDR"
MANIFEST="https://raw.githubusercontent.com/$REPO/main/latest.json"
WIRINGPI_API="https://api.github.com/repos/WiringPi/WiringPi/releases/latest"

YES=0; DEB=""; RUN_USER=""; DO_HW=1
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) YES=1 ;;
    --deb) DEB=${2:?--deb needs a file}; shift ;;
    --user) RUN_USER=${2:?--user needs a name}; shift ;;
    --no-hw) DO_HW=0 ;;
    -h|--help) sed -n '2,22p' "$0" 2>/dev/null || true; exit 0 ;;
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
# Pi 5's GPIO sits behind its RP1 chip: it needs WiringPi 3.0 or newer and
# Bookworm or later.
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
apt-cache show libasound2t64 >/dev/null 2>&1 && ASOUND=libasound2t64
apt-get install -y -q curl ca-certificates openssl python3 sudo alsa-utils unzip "$ASOUND" >/dev/null
ok "curl, openssl, python3, sudo, ALSA, unzip"

# gpsd: for a USB GPS receiver (position and time in the field). -n reads
# the receiver from boot, so GPS time is there before anything asks.
apt-get install -y -q gpsd >/dev/null && ok "gpsd (for a USB GPS receiver)" || warn "could not install gpsd"
if [ -f /etc/default/gpsd ] && grep -q '^GPSD_OPTIONS=""' /etc/default/gpsd; then
  sed -i 's/^GPSD_OPTIONS=""/GPSD_OPTIONS="-n"/' /etc/default/gpsd
  grep -q '^USBAUTO=' /etc/default/gpsd || echo 'USBAUTO="true"' >> /etc/default/gpsd
  systemctl enable gpsd >/dev/null 2>&1 || true
  systemctl restart gpsd >/dev/null 2>&1 || true
fi

# WiringPi drives the radio's GPIO. Its version: the package's, else what an
# installed "gpio" tool reports (a copy built from source has no package).
wiringpi_version() {
  local v
  v=$(dpkg-query -W -f='${Version}' wiringpi 2>/dev/null || true)
  if [ -z "$v" ] && command -v gpio >/dev/null 2>&1; then
    v=$(gpio -v 2>/dev/null | sed -n 's/^gpio version: *\([0-9][0-9.]*\).*/\1/p' | head -n 1)
  fi
  echo "$v"
}

install_wiringpi() {
  echo "    downloading WiringPi from github.com/WiringPi/WiringPi"
  URL=$(curl -fsSL "$WIRINGPI_API" | python3 -c '
import json, sys
for a in json.load(sys.stdin).get("assets", []):
    if a["name"].endswith("_arm64.deb"):
        print(a["browser_download_url"]); break')
  [ -n "$URL" ] || die "could not find the WiringPi arm64 package; install WiringPi 3.0 or newer yourself and run this again"
  curl -fsSL -o "$TMP/wiringpi.deb" "$URL"
  apt-get install -y -q "$TMP/wiringpi.deb" >/dev/null
  ok "WiringPi installed ($(basename "$URL"))"
}

WPV=$(wiringpi_version)
if ! ldconfig -p | grep -q libwiringPi; then
  install_wiringpi
elif [ "$PI5" = 1 ] && { [ -z "$WPV" ] || dpkg --compare-versions "$WPV" lt 3.0; }; then
  warn "WiringPi ${WPV:-(unknown version)} is too old for a Raspberry Pi 5 (it needs 3.0 or newer)"
  install_wiringpi
else
  ok "WiringPi ${WPV:-is installed}"
fi

# A WiringPi built from source lives in /usr/local/lib, which is searched
# before the package's copy: an old one there would still be the one jeSDR
# loads, and a Pi 5 needs 3.0 or newer.
if [ "$PI5" = 1 ]; then
  OLDWP=$(ls /usr/local/lib/libwiringPi*.so* 2>/dev/null || true)
  if [ -n "$OLDWP" ] && dpkg-query -W wiringpi >/dev/null 2>&1; then
    warn "an older WiringPi built from source is in /usr/local/lib and would be used instead of the new one"
    if ask "Move it aside (to /usr/local/lib/wiringpi-old)?"; then
      mkdir -p /usr/local/lib/wiringpi-old
      for f in /usr/local/lib/libwiringPi*.so* /usr/local/lib/libwiringPiDev*.so*; do
        [ -e "$f" ] && mv "$f" /usr/local/lib/wiringpi-old/
      done
      [ -x /usr/local/bin/gpio ] && mv /usr/local/bin/gpio /usr/local/lib/wiringpi-old/ 2>/dev/null || true
      ldconfig
      ok "moved; jeSDR now uses WiringPi $(dpkg-query -W -f='${Version}' wiringpi)"
    else
      warn "jeSDR may not start on this Pi 5 until the old WiringPi in /usr/local/lib is removed"
    fi
  fi
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

  # Kernel I2C for the Si5351, SWR bridge and INA260 (the zBitx's line)
  I2CLINE='dtoverlay=i2c-gpio,bus=3,i2c_gpio_sda=13,i2c_gpio_scl=6'
  if [ -c /dev/i2c-3 ] && grep -Eq '^[[:space:]]*dtoverlay=i2c-gpio' "$CFG" 2>/dev/null; then
    ok "kernel I2C bus is set up (/dev/i2c-3)"
  elif grep -Eq '^[[:space:]]*dtoverlay=i2c-gpio' "$CFG" 2>/dev/null; then
    ok "kernel I2C bus is set up in $CFG (active after a reboot)"
    REBOOT=1
  elif [ -f "$CFG" ]; then
    if ask "Let the kernel drive the radio's I2C bus (adds '$I2CLINE' to $CFG)?"; then
      [ -f "$CFG.jesdr-backup" ] || cp "$CFG" "$CFG.jesdr-backup"
      printf '\n[all]\n# jeSDR: the kernel drives the sBitx I2C bus (Si5351, SWR bridge, INA260)\n%s\n' "$I2CLINE" >> "$CFG"
      mkdir -p /var/lib/jeSDR && echo added > /var/lib/jeSDR/i2c-overlay
      ok "added (backup: $CFG.jesdr-backup)"
      REBOOT=1
    else
      # don't let the package add it later either
      mkdir -p /var/lib/jeSDR && echo declined > /var/lib/jeSDR/i2c-overlay
    fi
  fi

  # Three ALSA loopback cards, numbered 1, 2 and 3
  if grep -rqs 'snd-aloop\|snd_aloop' /etc/modprobe.d/ /etc/modules /etc/modules-load.d/; then
    NLOOP=$(aplay -l 2>/dev/null | grep -c '^card .*Loopback.*device 0' || true)
    if [ "$NLOOP" -ge 3 ]; then
      ok "ALSA loopback is set up ($NLOOP loopback cards)"
    else
      ok "ALSA loopback is configured (checked after the reboot)"
      warn "jeSDR needs three loopback cards: options snd-aloop enable=1,1,1 index=1,2,3"
    fi
  else
    warn "the ALSA loopback cards are not set up"
    if ask "Set up three loopback cards (for WSJT-X, fldigi and SDR apps)?"; then
      mkdir -p /etc/modprobe.d /etc/modules-load.d
      echo "options snd-aloop enable=1,1,1 index=1,2,3" > /etc/modprobe.d/jesdr-aloop.conf
      echo "snd-aloop" > /etc/modules-load.d/jesdr-aloop.conf
      ok "added /etc/modprobe.d/jesdr-aloop.conf"
      REBOOT=1
    fi
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

# ------------------------------------------------------------ 6. finish
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
