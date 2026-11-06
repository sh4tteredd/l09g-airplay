# 06 — Troubleshooting (every trap, with fix)

- `disabled on stable-channel` in `dropbear.log` → [02-root-ssh.md](02-root-ssh.md) channel fix.
- `sshd_keys -t ed25519` fails → use ecdsa (no ed25519 support).
- `[: not found` → firmware sh has no `[`/`test`; use `case`.
- `wpa_supplicant` exit 255 in ramfs → Android build, needs full init; config-only in ramfs.
- Serial drops → `tio -o 5`, one line at a time, no long heredocs over UART.
- `/dev/mtdblockN` missing in normal boot → use `/dev/block/mtdblockN`.
- `mtd0` ECC errors → `dd conv=noerror,sync` + trim one pad block.
- Mac `nc -l PORT` parses port as IP → Python listener (§03).
- `getaddrinfo: Try again` in chroot → missing `resolv.conf`/`hosts` copies.
- `Failed to start message bus` → missing passwd/group users + `/run/dbus`.
- Avahi `socket() failed: Permission denied` → seccomp vs dropped privs; run
  `--no-chroot --no-drop-root`.
- Avahi invisible while shairport lives → `avahi-daemon --check` first; that
  pair (not shairport) is always the casualty.
- Hook double-fire murders avahi → lockfile guard (in [files/start.sh](../files/start.sh)).
- `pidof`/`killall` do NOT match `avahi-daemon` (rewritten argv) → `pkill -9 -f`.
- Master resets to 20% every boot → `amixer sset` in [start.sh](../files/start.sh) or manually.
- Mixer `Failed to attach` → expected (no `mixer_control_name`); iPhone volume
  stays software. Mute/SPK labels lie on this driver — don't chase them.
- Update safety: kill-loop + stopped services are layers; router WAN-block is
  the definitive one (Xiaomi `eu.api.miwifi.com` + Google Omaha).
