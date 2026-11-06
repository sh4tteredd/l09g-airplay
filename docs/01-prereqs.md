# 01 — Prerequisites

- Xiaomi L09G (Mi Smart Speaker, Global). Other models differ — do not apply blindly.
- UART access: `J5` header (RX, GND, TX), 115200 8N1, 3.3 V USB-TTL adapter.
- Terminal with per-character pacing for long pastes: `tio -b 115200 -o 5 /dev/ttyUSB0`.
- Same-LAN WiFi credentials (SSID + PSK) for the final config.
- Mac (or Linux) with `nc`, `python3`, `shasum`; OrbStack (or any aarch64 Linux)
  for the chroot build in step 04.
- Patience for one full backup (~250 MB over WiFi).

Before anything: confirm U-Boot prompt (`axg_s420_v1_gva#`) by interrupting
boot with Enter. That prompt is your recovery path for the whole project.
