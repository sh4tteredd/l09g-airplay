# 05 — Deploy, persist, verify, rollback

## Push (Mac http.server + speaker wget — `nc -l` receive truncates)

```bash
cd <dir-with-tarball> && python3 -m http.server 8000 &
```

Speaker:

```sh
mkdir -p /data/airplay
/sbin/busybox wget http://<MAC_IP>:8000/<tarball> -O /data/airplay/chroot.tgz
sha256sum /data/airplay/chroot.tgz   # must match Mac
mkdir -p /data/airplay/root
/sbin/busybox tar -xzf /data/airplay/chroot.tgz -C /data/airplay/root
cp /etc/resolv.conf /data/airplay/root/etc/resolv.conf
printf '127.0.0.1 localhost\n' > /data/airplay/root/etc/hosts
chroot /data/airplay/root /usr/local/bin/shairport-sync -V
```

Expect `5.6.1-AirPlay2-smi11-...`.

## Persist ([files/start.sh](../files/start.sh) + hook)

Copy [files/start.sh](../files/start.sh) to `/data/airplay/start.sh` (0755). It backgrounds a
worker that: waits for `wlan0`, cleans stale daemons/pids, bind-mounts
`/dev`+`proc`+`sys`, stops the Cast stack in a 30 s loop (Cast starts *after*
the hook — without the loop dev2/UDP-5353 stay taken), starts
dbus→avahi→nqptp→shairport, stops `panel_service` (blink), then plays the
boot signal (10 s → green ring 5 s → dark). Lockfile guard kills double-fire.

Hook (overlay, append only):

```sh
printf '\n# --- airplay ---\nsh /data/airplay/start.sh &\n' >> /usr/bin/insert_modules.sh
sync
reboot
```

## Verify (~3 min after reboot)

- `cat /data/airplay/boot.log`: net up → cast stopped → avahi check 0 → stack started → led signal done
- `aplay -l` dev2 `1/1`; `avahi-daemon: running [<NAME>.local]`
- Picker → NAME → stereo audio (~2 s latency normal; first play waits on PTP)
- `amixer -c 0 sset Master 800` (reboot resets it to 20%; add to [start.sh](../files/start.sh) if wanted)

## Rollback

AirPlay off, SSH kept: delete the `# --- airplay` block from
`/usr/bin/insert_modules.sh`, `sync`, reboot — Cast returns.
Full stock: additionally restore `/data/build.prop.bak` → `/system/build.prop`
and delete the overlay `insert_modules.sh`/`build.prop`, reboot.
