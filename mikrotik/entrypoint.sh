#!/bin/sh
# Seed /data on first start, then run YTuner with its ini file on /data.
set -e
mkdir -p /data/config
[ -f /data/ytuner.ini ] || cp /opt/ytuner/defaults/ytuner.ini /data/ytuner.ini
for f in /opt/ytuner/defaults/config/*; do
  [ -e "/data/config/${f##*/}" ] || cp "$f" /data/config/
done
ln -sf /data/ytuner.ini /opt/ytuner/ytuner.ini
cd /opt/ytuner
exec ./ytuner
