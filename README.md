# HIVEHUB

A grimdark web-based campaign map manager for **Necromunda** (N26 ruleset).
Built for Arbitrators to manage gang territory across campaign seasons.

> **Disclaimer**: Necromunda, Warhammer 40,000 and all associated names,
> marks and settings are the intellectual property of Games Workshop Ltd.
> HIVEHUB is an unofficial, non-commercial fan-made tool for gamers and is
> in no way endorsed by or affiliated with Games Workshop.

If you find it useful, you can
[support this site's running costs](https://buymeacoffee.com/astromoose). ☕

## Stack

- Ruby + Sinatra
- Sequel ORM + SQLite
- Vanilla JavaScript + SVG hexmaps

## Running

```sh
bundle install
bundle exec rackup -p 9292
```

Then open http://localhost:9292.

## Configuration (environment variables)

| Variable | Purpose |
|---|---|
| `SESSION_SECRET` | Session cookie secret (random per-boot if unset — sessions won't survive restarts) |
| `HIVEHUB_DB` | Path to the SQLite database (default: `db/hivehub.sqlite3`) |
| `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` | Enable "Sign in with GitHub" (optional) |

### GitHub OAuth setup

1. On GitHub: **Settings → Developer settings → OAuth Apps → New OAuth App**
2. Homepage URL: `http://localhost:9292`
3. Authorization callback URL: `http://localhost:9292/auth/github/callback`
4. Export `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` before starting the app.

If the variables are unset, the GitHub button is hidden and only
username/password auth is available.

## Domain model

- **User (Arbitrator)** — has many campaigns; local (bcrypt) or GitHub identity
- **Campaign** — has many zones (seasons) and gangs
- **Zone** — one hexmap per season, sized per the Dominion territory table
  (3 turfs per gang, minimum 3 gangs, plus 2–6 at the Arbitrator's
  discretion) of randomly generated, connected turf hexes with Necromunda
  flavour text
- **Gang** — one of the 16 recognised affiliations, palette colour and a
  thematic icon ([game-icons.net](https://game-icons.net), CC BY 3.0 by
  Lorc, Delapouite & Carl Olsen) assigned on registration
- **Turf** — a hex on the zone map; typed as one of the 26 **Dominion
  Campaign territories** (Necromunda Core Rulebook 2023) with boon
  summaries; may be held by a gang, marked ⌂ if it is that gang's home

## Rules enforced

- New gangs are granted a random **unclaimed edge turf** as their home,
  which becomes a **Settlement** — every gang's unlosable Dominion
  starting territory
- At least **50% of every map is no-man's-land** at generation/claim time
- New seasons re-chart the map: gangs carry over and receive fresh home turf
- Arbitrators can reassign any turf by clicking a hex on the map

## Deployment

See [DEPLOY.md](DEPLOY.md) for running HIVEHUB on a small Hetzner Cloud VPS
(Caddy + Puma + systemd, ~€6/month).

## Munda Manager integration

HIVEHUB campaigns can link to a [Munda Manager](https://www.mundamanager.com)
campaign via its **public campaign data API** (no auth; rate limited to
10 requests/minute):

1. On the campaign page, paste the UUID from your Munda Manager campaign
   URL (`mundamanager.com/campaigns/<uuid>`) and establish the uplink.
2. **Import Gangs** pulls each member's gangs (name and house, normalised
   to HIVEHUB affiliations) and assigns home turf as usual. Gangs beyond
   map capacity are skipped and reported.
3. **Sync Stats** refreshes gang rating, credits and reputation, shown
   next to each imported gang in the roster.

Fighter-level data is not available through Munda Manager's public API.
