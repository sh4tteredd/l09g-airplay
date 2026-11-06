#!/bin/sh
LOG=/data/airplay/boot.log
(
mkdir /tmp/airplay-boot.lock 2>/dev/null || exit 0
echo "$(date) airplay boot wait" > "$LOG"
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
ip=$(ifconfig wlan0 2>/dev/null | grep -o "inet addr:[0-9.]*" | cut -d: -f2)
case "$ip" in
"") sleep 10 ;;
*) echo "$(date) net up $ip" >> "$LOG"; break ;;
esac
done
sleep 5
killall -9 shairport-sync 2>/dev/null
killall -9 nqptp 2>/dev/null
killall avahi-daemon 2>/dev/null
killall dbus-daemon 2>/dev/null
sleep 1
rm -f /data/airplay/root/run/dbus/dbus.pid
rm -f /data/airplay/root/var/run/dbus/pid
rm -f /data/airplay/root/var/run/avahi-daemon/pid
mkdir -p /data/airplay/root/proc /data/airplay/root/sys
mkdir -p /data/airplay/root/tmp /data/airplay/root/run/dbus
mount -o bind /dev /data/airplay/root/dev 2>/dev/null
mount -t proc proc /data/airplay/root/proc 2>/dev/null
mount -t sysfs sysfs /data/airplay/root/sys 2>/dev/null
for i in 1 2 3 4 5 6; do
setprop ctl.stop process_monitor
setprop ctl.stop mute_service
setprop ctl.stop ota_service
setprop ctl.stop cast_receiver
killall -9 process_manager 2>/dev/null
killall -9 cast_shell 2>/dev/null
killall mdnsd 2>/dev/null
sleep 5
done
echo "$(date) cast stopped" >> "$LOG"
chroot /data/airplay/root /usr/bin/dbus-daemon --system 2>>"$LOG"
sleep 1
chroot /data/airplay/root /usr/sbin/avahi-daemon --no-chroot --no-drop-root -D 2>>"$LOG"
chroot /data/airplay/root /usr/sbin/avahi-daemon --check 2>>"$LOG"
echo "$(date) avahi check $?" >> "$LOG"
setsid chroot /data/airplay/root /usr/bin/nqptp >>/data/airplay/nqptp.log 2>&1 < /dev/null &
setsid chroot /data/airplay/root /usr/local/bin/shairport-sync -o alsa -c /etc/shairport-sync.conf >>/data/airplay/shairport.log 2>&1 < /dev/null &
echo "$(date) stack started" >> "$LOG"
# Panel: stopped, never started. It crash-loops on the dead Cast socket and
# blinks the LED ring. (A start-then-stop pulse would also boot the button
# MCU, but buttons are out of scope for this repo — see docs.)
setprop ctl.stop panel_service
sleep 10
for i in $(seq 0 23); do echo "$i 65280" > /sys/devices/platform/soc/ff800000.aobus/ff805000.i2c/i2c-1/1-003b/led_rgb; done
sleep 5
for i in $(seq 0 23); do echo "$i 0" > /sys/devices/platform/soc/ff800000.aobus/ff805000.i2c/i2c-1/1-003b/led_rgb; done
echo "$(date) led signal done" >> "$LOG"
) &
