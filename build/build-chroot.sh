#!/bin/sh
# build-chroot.sh — supervised one-shot AirPlay chroot build.
#
# WHERE TO RUN: any Alpine 3.23 **aarch64** shell — container, VM, or bare metal.
#   (NOT macOS directly: wrong libc and toolchain.)
#   Docker, arm64 host (native, fast):
#     mkdir -p out
#     docker run --rm -v "$PWD/out:/out" -e OUT=/out/l09g-airdrop-chroot.tar.gz \
#       alpine:3.23 sh -c 'apk add curl sudo && curl -fsSL https://raw.githubusercontent.com/sh4tteredd/l09g-airdrop/main/build/build-chroot.sh | sh'
#   Docker, amd64 host (emulated — works, slower FFmpeg build):
#     same, plus --platform linux/arm64
#   OrbStack (Apple Silicon):
#     orb create alpine:3.23 airplay-build
#     orb -m airplay-build sh < build/build-chroot.sh
#   1. installs compilers + audio/mDNS/crypto dev libraries
#   2. builds nqptp (PTP clock, tiny, musl-only)
#   3. builds a minimal static FFmpeg (ALAC/AAC decode + resample only —
#      the distro FFmpeg would drag 100+ MB of video/X11/Vulkan libs)
#   4. builds shairport-sync against the minimal FFmpeg (AirPlay 2)
#   5. checks the pair cryptographically agree (smi version both sides)
#   6. assembles the chroot (base libs + both binaries + required fixes)
#   7. writes the tarball to $OUT and prints what to do next
# Knobs: AIRPLAY_NAME (default Speaker), OUT (default below),
#   WORK (scratch dir). Runs as root or via sudo.
set -e
say() { echo "== $1"; }
die() { echo "!! $1" >&2; exit 1; }

[ "$(uname -m)" = "aarch64" ] || die "need aarch64 Linux (got $(uname -m): use --platform linux/arm64, or build on the speaker's arch)"
command -v apk >/dev/null || die "needs Alpine Linux (apk not found)"
if [ "$(id -u)" = "0" ]; then SUDO=""; elif command -v sudo >/dev/null; then SUDO="sudo"; else die "need root or sudo"; fi

SPS_VERSION=5.6.1
NQPTP_VERSION=1.2.9
FF_VERSION=8.1.2
FF_SHA256=464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c
WORK=${WORK:-$HOME/apbuild}
FFOUT=$WORK/ff-out
ROOT=$WORK/l09g-chroot
OUT=${OUT:-$HOME/l09g-airdrop-chroot.tar.gz}
NAME=${AIRPLAY_NAME:-Speaker}

say "1/7 dependencies"
$SUDO apk add autoconf automake libtool git build-base alsa-lib-dev avahi-dev \
  openssl-dev libconfig-dev popt-dev soxr-dev libplist-dev libsodium-dev \
  libgcrypt-dev util-linux-dev ffmpeg-dev dbus avahi libplist-util curl

say "2/7 sources (nqptp $NQPTP_VERSION)"
mkdir -p "$WORK"
cd "$WORK"
[ -d nqptp-src ] || git clone --depth 1 --branch $NQPTP_VERSION https://github.com/mikebrady/nqptp.git nqptp-src
(cd nqptp-src && autoreconf -fi && ./configure && make -j4)
nv=$(grep -o 'NQPTP_SHM_STRUCTURES_VERSION [0-9]*' nqptp-src/nqptp-shm-structures.h | cut -d' ' -f2)
say "nqptp smi$nv built"

say "3/7 minimal FFmpeg $FF_VERSION (audio codecs only, static)"
[ -f ffmpeg-$FF_VERSION.tar.xz ] || curl -fsSL -o ffmpeg-$FF_VERSION.tar.xz https://ffmpeg.org/releases/ffmpeg-$FF_VERSION.tar.xz
echo "$FF_SHA256  ffmpeg-$FF_VERSION.tar.xz" | sha256sum -c -
rm -rf ffmpeg ff-out; mkdir ffmpeg
tar -xf ffmpeg-$FF_VERSION.tar.xz -C ffmpeg --strip-components=1
(cd ffmpeg && ./configure --prefix="$FFOUT" --target-os=linux --arch=aarch64 \
  --disable-autodetect --disable-everything --disable-doc --disable-debug \
  --disable-programs --disable-avdevice --disable-avfilter --disable-swscale \
  --disable-network --enable-static --disable-shared --enable-pthreads \
  --enable-avcodec --enable-avformat --enable-avutil --enable-swresample \
  --enable-decoder=alac,aac && make -j4 && make install)
ls "$FFOUT/lib/"*.a

say "4/7 shairport-sync $SPS_VERSION (AirPlay 2, against minimal FFmpeg)"
[ -d sps-src ] || git clone --depth 1 --branch $SPS_VERSION https://github.com/mikebrady/shairport-sync.git sps-src
(cd sps-src && autoreconf -fi && \
  PKG_CONFIG_LIBDIR="$FFOUT/lib/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig" \
  ./configure --with-airplay-2 --with-alsa --with-avahi --with-ssl=openssl \
  --with-soxr --with-metadata && make -j4)
grep -q '^#define CONFIG_AIRPLAY_2 1' sps-src/config.h \
  || die "AirPlay 2 not enabled — check configure output"

say "5/7 pair check (shared-memory versions must match)"
sv=$(grep -o 'NQPTP_SHM_STRUCTURES_VERSION [0-9]*' sps-src/nqptp-shm-structures.h | cut -d' ' -f2)
[ -n "$sv" ] && [ "$sv" = "$nv" ] || die "smi mismatch shairport=$sv nqptp=$nv"
say "smi$nv both sides, AirPlay 2 confirmed"
ldd sps-src/shairport-sync | grep -i -e x11 -e vulkan && die "full FFmpeg leaked in — rebuild clean" || true

say "6/7 chroot assembly"
$SUDO rm -rf "$ROOT" && $SUDO mkdir -p "$ROOT/etc/apk"
$SUDO cp /etc/apk/repositories "$ROOT/etc/apk/"
$SUDO apk --root "$ROOT" --initdb --no-cache --keys-dir /usr/share/apk/keys \
  add musl busybox alsa-lib avahi dbus libconfig popt soxr libcrypto3 libssl3 \
  libsodium libgcrypt libgpg-error libplist libuuid gettext-libs libgcc libgomp
(cd sps-src && $SUDO make install DESTDIR="$ROOT")
$SUDO cp nqptp-src/nqptp "$ROOT/usr/bin/"
# Each fix below was a real on-device failure, in order encountered:
$SUDO sh -c "printf 'root:x:0:0:root:/root:/bin/sh\ndbus:x:81:81:dbus:/var/run/dbus:/bin/false\navahi:x:82:82:avahi:/var/run/avahi-daemon:/bin/false\nmessagebus:x:83:83:messagebus:/var/run/dbus:/bin/false\n' > $ROOT/etc/passwd"
$SUDO sh -c "printf 'root:x:0:\ndbus:x:81:\nnetdev:x:82:\navahi:x:82:\nmessagebus:x:83:\n' > $ROOT/etc/group"
$SUDO mkdir -p "$ROOT/tmp" "$ROOT/run/dbus"
$SUDO sh -c "printf 'general = { name = \"$NAME\"; port = 7000; };\nalsa = { output_device = \"plughw:AMLAUGESOUND,2\"; };\n' > $ROOT/etc/shairport-sync.conf"
$SUDO sed -i "s/^#host-name=.*/host-name=$NAME/" "$ROOT/etc/avahi/avahi-daemon.conf"
$SUDO tar -czf "$OUT" -C "$ROOT" .
$SUDO du -sh "$ROOT"

say "7/7 done: $OUT"
ls -lh "$OUT"
echo "Next: get the tarball onto your build host if it was built elsewhere,"
echo "then continue with docs/05-deploy-run.md"
