# 03 — Full NAND backup

Normal-boot block nodes are `/dev/block/mtdblockN`. `mtd0` has ECC bad blocks:
always `conv=noerror,sync`. macOS `nc -l PORT` misparses the port as an IP —
use the Python listener. Stream device → Mac (never store dumps on `/data`).

| mtd | name | bytes | `count` (bs=131072) | port |
|---|---|---|---|---|
| 0 bootloader | 2097152 | 16 | 10000 |
| 1 tpl | 8388608 | 64 | 10001 |
| 2 recovery | 10485760 | 80 | 10002 |
| 3 boot | 12582912 | 96 | 10003 |
| 4 system | 16777216 | 128 | 10004 |
| 5 chrome | 71303168 | 544 | 10005 |
| 6 factory | 4194304 | 32 | 10006 |
| 7 data | 136314880 | 1040 | 10007 |

Per partition — Mac (waits):

```bash
OUT=backup-l09g-$(date +%Y%m%d-%H%M); mkdir -p "$OUT"
python3 -c "import socket; s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(('0.0.0.0',10000)); s.listen(1); c,_=s.accept(); open('$OUT/mtd0.bin','wb').write(c.makefile('rb').read())"
```

Speaker (telnet/SSH, while Mac waits):

```sh
/sbin/busybox dd if=/dev/block/mtdblock0 bs=131072 conv=noerror,sync count=16 2>/tmp/dd0.err | /sbin/busybox nc <MAC_IP> 10000
```

`mtd0` arrives one eraseblock oversize (pad) — `head -c 2097152` it. Then:

```bash
ls -l "$OUT/"; shasum -a 256 "$OUT"/mtd*.bin > "$OUT/SHA256SUMS"
file "$OUT"/mtd*.bin
```

Expect: mtd2/mtd3 Android bootimg, mtd4/mtd5 squashfs xz, mtd6/mtd7 UBI.
`mtd7` is UBIFS-mounted: `sync` first, treat as best-effort. Keep two copies.
