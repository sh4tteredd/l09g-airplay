# l09g-airplay

Turn a stock Xiaomi Mi Smart Speaker (L09G, Global) into a dedicated,
persistent **AirPlay 2** receiver. No Cast, no buttons, no voice — one job.

End state: root SSH on port 2222, full NAND backup in hand, Alpine chroot on
`/data` running `shairport-sync` 5.6.1 + `nqptp` 1.2.9 as **Speaker**,
Cast stack stopped, green-ring boot signal, dark idle LEDs.

**Never touch `boot`/`recovery`** (signed + encrypted). Everything here writes
only to the `data` partition and the `/system` overlay. Keep UART/U-Boot
access until the end.

## Order

1. [docs/01-prereqs.md](docs/01-prereqs.md) — hardware, tools
2. [docs/02-root-ssh.md](docs/02-root-ssh.md) — ramfs shell, overlay, SSH, channel fix, WiFi
3. [docs/03-backup.md](docs/03-backup.md) — dump every partition, verify
4. [docs/04-build-chroot.md](docs/04-build-chroot.md) — build the AirPlay userland (or [build/](build/))
5. [docs/05-deploy-run.md](docs/05-deploy-run.md) — push, persist, verify, rollback
6. [docs/06-troubleshooting.md](docs/06-troubleshooting.md) — every trap we hit, with fixes

[VERSIONS](VERSIONS) pins every input. [files/](files/) holds the exact device scripts.
