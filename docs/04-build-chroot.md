# 04 — Build the AirPlay chroot

Why a chroot, and why here: the speaker runs bionic/Android with no compiler
and ~109 MB free. Packages are therefore built for aarch64-musl on a separate
Linux machine and shipped as a tarball. **Do not build on macOS** (wrong libc,
wrong toolchain) — any Alpine 3.23 aarch64 shell works: VM, bare metal,
or container (see Docker commands below).

## Run it (one command, supervised)

```bash
mkdir -p out
docker run --rm -v "$PWD/out:/out" -e OUT=/out/l09g-airdrop-chroot.tar.gz \
  alpine:3.23 sh -c 'apk add curl sudo && curl -fsSL https://raw.githubusercontent.com/sh4tteredd/l09g-airdrop/main/build/build-chroot.sh | sh'
```

On amd64 hosts add `--platform linux/arm64` (emulated: works, slower FFmpeg
build). Tarball lands at `out/l09g-airdrop-chroot.tar.gz` (~8 MB).
Alternative without Docker (OrbStack on Apple Silicon):

```bash
orb create alpine:3.23 airplay-build
orb -m airplay-build sh < build/build-chroot.sh
# then: orb pull -m airplay-build l09g-airdrop-chroot.tar.gz out/
```

Supervised means: the script prints `== 1/7 … 7/7` banners, verifies each
stage (tarball sha256, `CONFIG_AIRPLAY_2`, smi match both sides, no X11 in
`ldd`), and **stops on the first error** with a `!!` line telling you what
broke. Expected wall time: ~10–20 min (FFmpeg dominates). Result on the
machine: `~/l09g-airdrop-chroot.tar.gz` (~8 MB).

Change the speaker name with `AIRPLAY_NAME=Ufficio orb -m airplay-build …`
(default `Speaker`).

## What the 7 stages do and why

1. **Dependencies** — compilers, autotools, git, plus the exact `-dev`
   headers shairport needs (ALSA, Avahi, OpenSSL, soxr, plist, sodium…).
   Note `libplist-util`: that package (not `libplist-dev`) provides the
   `plistutil` binary AirPlay 2 requires.
2. **nqptp 1.2.9** — the PTP clock AirPlay 2 syncs to. Tiny, musl-only.
   Records its shared-memory version (smi11).
3. **Minimal static FFmpeg 8.1.2** — audio codecs only (ALAC/AAC decode +
   resample), statically linked. The distro FFmpeg would drag 100+ MB of
   video/X11/Vulkan libraries — the single biggest size trap in this build.
4. **shairport-sync 5.6.1** — configured `--with-airplay-2 --with-alsa
   --with-avahi --with-ssl=openssl --with-soxr --with-metadata`, pointed at
   the minimal FFmpeg via `PKG_CONFIG_LIBDIR` so the small codecs win.
5. **Pair check** — both binaries must agree on the nqptp shared-memory
   layout (smi); mismatched versions fail here loudly instead of silently
   at runtime.
6. **Chroot assembly (~20 MB)** — `apk --root` base (musl, busybox, ALSA,
   Avahi, D-Bus, crypto…), `make install`, then four fixes, each earned by a
   real on-device failure: minimal `passwd`/`group` (dbus/avahi users),
   `resolv.conf`+`hosts` copies (DNS inside chroot), `/tmp`+`/run/dbus`,
   speaker config + Avahi host-name.
7. **Tarball** — packed, measured, with next-step instructions printed.

## Get the tarball to your Mac

```bash
orb pull -m airplay-build l09g-airdrop-chroot.tar.gz .
ls -lh l09g-airdrop-chroot.tar.gz
```

Continue with [05-deploy-run.md](05-deploy-run.md).
