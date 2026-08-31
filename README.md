# HIVEHUB

A grimdark web-based campaign map manager for **Necromunda** (N26 ruleset).
Built for Arbitrators to manage gang territory across campaign seasons.

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
- **Zone** — one hexmap per season; 12–20 randomly generated, connected turf hexes with Necromunda flavour text
- **Gang** — one of the 16 recognised affiliations, palette colour assigned on registration
- **Turf** — a hex on the zone map; may be held by a gang, marked ⌂ if it is that gang's home

## Rules enforced

- New gangs are granted a random **unclaimed edge turf** as their home
- At least **50% of every map is no-man's-land** at generation/claim time
- New seasons re-chart the map: gangs carry over and receive fresh home turf
- Arbitrators can reassign any turf by clicking a hex on the map
