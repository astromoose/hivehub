# Deploying HIVEHUB to Hetzner Cloud

Target: **CX23** (2 vCPU, 4 GB RAM, 40 GB NVMe, 20 TB traffic) with IPv4 —
**€5.99/mo net** (~€7.13 incl. 19% VAT). No setup fees. Hetzner DNS is free.

Stack: Caddy (auto-HTTPS) → Puma (systemd) → Sinatra + SQLite.
Idle footprint is ~400 MB RAM — enormous headroom on 4 GB.

## 1. Create the server

1. Sign up / log in at [console.hetzner.com](https://console.hetzner.com),
   create a project (e.g. `hivehub`).
2. Add your SSH public key under **Security → SSH keys**.
3. **Create server**:
   - Location: Nuremberg or Falkenstein or Helsinki (all EU, 20 TB traffic)
   - Image: **Ubuntu 24.04**
   - Type: Shared vCPU → x86 → **CX23**
   - Networking: **IPv4 + IPv6** (IPv4 is the €0.50/mo that keeps life simple)
   - Volumes: none needed — the included 40 GB NVMe is plenty
   - Firewall: optional; `setup.sh` configures ufw on the host. A free
     Hetzner Cloud Firewall allowing TCP 22/80/443 is a fine extra layer
   - Backups: optional (+20% ≈ €1.20/mo) — the app already snapshots its
     database daily
   - SSH key: select yours
4. Note the server's IPv4 and IPv6 addresses.

## 2. Point DNS at it

**Option A — free Hetzner DNS** (recommended if dirtyblades.com has no DNS
records you care about yet):

1. At [dns.hetzner.com](https://dns.hetzner.com), add zone `dirtyblades.com`
   (skip auto-import if the domain is unused).
2. At your registrar, set the domain's nameservers to
   `hydrogen.ns.hetzner.com`, `oxygen.ns.hetzner.com`, `helium.ns.hetzner.de`.
3. In the Hetzner zone, add records:
   - `A` — name `hivehub`, value `<server IPv4>`
   - `AAAA` — name `hivehub`, value `<server IPv6>`

**Option B — keep your current DNS provider** (e.g. Hover): just add the same
`A`/`AAAA` records for `hivehub.dirtyblades.com` there. On Hover: domain →
**DNS** → **Add a record** → type `A`, hostname `hivehub`, value = server
IPv4; repeat with type `AAAA` for the server IPv6.

Nameserver changes can take a few hours to propagate; the records themselves
are fast.

## 3. Provision

SSH in and run the setup script (installs Ruby, Caddy, the app, systemd
units, firewall, daily backups):

```bash
ssh root@<server-ip>
apt-get update && apt-get install -y git
git clone https://github.com/astromoose/hivehub.git /opt/hivehub
DOMAIN=hivehub.dirtyblades.com bash /opt/hivehub/deploy/setup.sh
```

That's it. Once DNS resolves, Caddy fetches a Let's Encrypt certificate
automatically on the first request to <https://hivehub.dirtyblades.com>.

### Optional: GitHub OAuth login

Create an OAuth app at <https://github.com/settings/developers> with callback
URL `https://hivehub.dirtyblades.com/auth/github/callback`, then:

```bash
vi /etc/hivehub.env    # fill in GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET
systemctl restart hivehub
```

## 4. Updating

After pushing to `main`:

```bash
ssh root@<server-ip> 'bash /opt/hivehub/deploy/update.sh'
```

## 5. Backups

A systemd timer (`hivehub-backup.timer`) snapshots the SQLite database daily
to `/var/lib/hivehub/backups/` with 14-day retention, using SQLite's online
`.backup` (safe while the app runs). To pull a copy off-site:

```bash
scp root@<server-ip>:/var/lib/hivehub/backups/hivehub-daily.sqlite3 .
```

To migrate an existing local database up:

```bash
systemctl stop hivehub
scp db/hivehub.sqlite3 root@<server-ip>:/var/lib/hivehub/hivehub.sqlite3
ssh root@<server-ip> 'chown hivehub:hivehub /var/lib/hivehub/hivehub.sqlite3 && systemctl start hivehub'
```

## Operations cheat-sheet

```bash
systemctl status hivehub          # app status
journalctl -u hivehub -f          # app logs
systemctl status caddy            # proxy status
journalctl -u caddy -f            # proxy/TLS logs
systemctl list-timers hivehub-*   # backup schedule
```

## Cost summary

| Item | €/mo (net) |
|---|---|
| CX23 server | 5.49 |
| Primary IPv4 | 0.50 |
| Hetzner DNS | 0 |
| TLS (Let's Encrypt via Caddy) | 0 |
| **Total** | **5.99** (~€7.13 incl. 19% VAT) |
