#!/usr/bin/env bash
# HIVEHUB update: pull latest main, install gems, restart. Run as root.
set -euo pipefail

APP_DIR=/opt/hivehub

echo "==> Updating HIVEHUB"
sudo -u hivehub -H sh -c "cd $APP_DIR && git pull --ff-only && bundle install --quiet"

# Pick up any changed units/Caddyfile
cp "$APP_DIR/deploy/hivehub.service" /etc/systemd/system/
cp "$APP_DIR/deploy/hivehub-backup.service" /etc/systemd/system/
cp "$APP_DIR/deploy/hivehub-backup.timer" /etc/systemd/system/
systemctl daemon-reload

systemctl restart hivehub
sleep 2
systemctl --no-pager --lines 0 status hivehub | head -3
curl -s -o /dev/null -w "==> app responds: HTTP %{http_code}\n" http://127.0.0.1:9292/login
