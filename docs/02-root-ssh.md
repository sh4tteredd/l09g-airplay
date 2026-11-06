# 02 — Root shell, overlay, SSH

All RAM-only until step 4 (no `saveenv` — a power cycle reverts everything).

## Ramfs root shell

At the U-Boot prompt paste one line, verify it ends with `exec /bin/ash"`,
then boot:

```text
setenv bootargs 'rootfstype=ramfs rdinit=/sbin/busybox console=ttyS0,115200 no_console_suspend earlycon=aml_uart,0xff803000 -- ash -c "/sbin/busybox mkdir -p /proc /sys /dev /system /bin; /sbin/busybox mount -t proc proc /proc; /sbin/busybox mount -t sysfs sysfs /sys; /sbin/busybox mount -t devtmpfs devtmpfs /dev; /sbin/busybox mount -t squashfs -o ro /dev/mtdblock4 /system; /sbin/busybox --install -s /bin; export LD_LIBRARY_PATH=/system/lib; exec /bin/ash"'
printenv bootargs
run storeboot
```

Mount persistent storage (`data` = UBI on `mtd7`):

```sh
/sbin/ubiattach /dev/ubi_ctrl -m 7
mkdir -p /pers
mount -t ubifs /dev/ubi0_0 /pers
ls -la /pers
```

`/pers/.data` is `/data` at runtime; `/pers/.system.overlay` is the writable
upper layer over the read-only `/system` squashfs.

## Passwordless root + host key (ecdsa only — no ed25519 on this firmware)

```sh
mkdir -p /pers/.system.overlay/etc /pers/.data/root
echo 'root::0:0:root:/data/root:/bin/sh' > /pers/.system.overlay/etc/passwd
chmod 0644 /pers/.system.overlay/etc/passwd
mkdir -p /pers/.data/ssh
/system/usr/bin/sshd_keys -t ecdsa -f /pers/.data/ssh/dropbear_ecdsa_host_key
```

## `start_ssh.sh`

Copy [files/start_ssh.sh](../files/start_ssh.sh) to `/pers/.data/ssh/start_ssh.sh` (mode 0755):
sshd on 2222 with blank-password login, an `update_engine` kill-loop, and a
telnet fallback on 2323 (keep during bring-up; remove the line for hardening).

## Boot hook (append only — keeps the WLAN driver lines)

```sh
cp /system/usr/bin/insert_modules.sh /pers/.system.overlay/usr/bin/insert_modules.sh
printf '\n# --- persistent ssh + no-ota ---\nsh /data/ssh/start_ssh.sh &\n' >> /pers/.system.overlay/usr/bin/insert_modules.sh
chmod 0755 /pers/.system.overlay/usr/bin/insert_modules.sh
```

## The `stable-channel` gate

`dropbearmulti` refuses to start when `ro.product.release.track=stable-channel`
(log: `disabled on stable-channel`). Fix after first normal boot (via telnet):

```sh
cp /system/build.prop /data/build.prop.bak
grep -v '^ro.product.release.track=' /system/build.prop > /tmp/build.prop
echo 'ro.product.release.track=' >> /tmp/build.prop
cat /tmp/build.prop > /system/build.prop
sync
reboot
```

Verify: `getprop ro.product.release.track` empty, `ssh -p 2222 root@<IP>`
(empty password) works. Revert: restore the `.bak` file.

## WiFi

Keep the existing `/pers/.data/wifi/wpa_supplicant.conf` if provisioned;
otherwise write SSID/PSK (plaintext PSK accepted). Then `sync`, `reboot`,
find the IP (hostname `Chromecast`/`xiaomi`, MAC `9c:9d:…` range).
