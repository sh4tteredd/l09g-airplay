#!/bin/sh
/system/usr/bin/sshd -R -r /data/ssh/dropbear_ecdsa_host_key -B -p 2222 -E >> /data/ssh/dropbear.log 2>&1
( while : ; do /system/bin/killall update_engine 2>/dev/null ; /system/bin/sleep 5 ; done ) &
/sbin/busybox telnetd -p 2323 -l /bin/sh
