#!/usr/bin/env bash
# HIVEHUB one-shot server setup for a fresh Ubuntu 24.04 Hetzner Cloud VPS.
# Run as root:  DOMAIN=hivehub.dirtyblades.com bash /opt/hivehub/deploy/setup.sh
set -euo pipefail

DOMAIN="${DOMAIN:-hivehub.dirtyblades.com}"
REPO="${REPO:-https://github.com/astromoose/hivehub.git}"
APP_DIR=/opt/hivehub
DATA_DIR=/var/lib/hivehub

echo "==> HIVEHUB setup for ${DOMAIN}"

echo "==> Installing packages"
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -qy \
  ruby-full build-essential git libsqlite3-dev sqlite3 libyaml-dev pkg-config \
  debian-keyring debian-archive-keyring apt-transport-https curl ufw
command -v bundle > /dev/null || gem install bundler --no-document

echo "==> Installing Caddy (official repo)"
if ! command -v caddy > /dev/null; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -q
  apt-get install -qy caddy
fi

echo "==> Creating hivehub user and directories"
id -u hivehub &> /dev/null || useradd --system --home-dir "$APP_DIR" --shell /usr/sbin/nologin hivehub
mkdir -p "$DATA_DIR/backups"

echo "==> Fetching application"
if [ ! -d "$APP_DIR/.git" ]; then
  git clone "$REPO" "$APP_DIR"
fi
chown -R hivehub:hivehub "$APP_DIR" "$DATA_DIR"

echo "==> Installing gems"
sudo -u hivehub -H sh -c "cd $APP_DIR && bundle config set --local path vendor/bundle && bundle install --quiet"

echo "==> Writing /etc/hivehub.env"
if [ ! -f /etc/hivehub.env ]; then
  cat > /etc/hivehub.env <<EOF
RACK_ENV=production
APP_ENV=production
HIVEHUB_DB=$DATA_DIR/hivehub.sqlite3
SESSION_SECRET=$(openssl rand -hex 64)
# Optional GitHub OAuth (create an app at github.com/settings/developers,
# callback URL: https://$DOMAIN/auth/github/callback), then restart hivehub:
#GITHUB_CLIENT_ID=
#GITHUB_CLIENT_SECRET=
EOF
  chmod 600 /etc/hivehub.env
fi

echo "==> Installing systemd units"
cp "$APP_DIR/deploy/hivehub.service" /etc/systemd/system/
cp "$APP_DIR/deploy/hivehub-backup.service" /etc/systemd/system/
cp "$APP_DIR/deploy/hivehub-backup.timer" /etc/systemd/system/
systemctl daemon-reload

echo "==> Configuring Caddy for ${DOMAIN}"
sed "s/^HIVEHUB_DOMAIN/${DOMAIN}/" "$APP_DIR/deploy/Caddyfile" > /etc/caddy/Caddyfile

echo "==> Firewall (SSH, HTTP, HTTPS)"
ufw allow OpenSSH > /dev/null
ufw allow 80/tcp > /dev/null
ufw allow 443/tcp > /dev/null
ufw --force enable > /dev/null

echo "==> Starting services"
systemctl enable --now hivehub hivehub-backup.timer
systemctl reload caddy || systemctl restart caddy

echo
echo "==> Done. Checks:"
systemctl --no-pager --lines 0 status hivehub | head -3
curl -s -o /dev/null -w "    local app responds: HTTP %{http_code}\n" http://127.0.0.1:9292/login
echo "    Once DNS for ${DOMAIN} points here, Caddy will fetch a TLS cert"
echo "    automatically on first request: https://${DOMAIN}"
