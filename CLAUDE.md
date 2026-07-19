# CLAUDE.md — beam-campus-net

The public website for **BEAM Campus**, the research commons. Phoenix LiveView,
mirroring `macula-internal/macula-realm`'s operational practices.

## What this is (and is not)

- It **is** a content/landing site: the thesis, the substrate, the commons value
  theory, the three asks (run a node / patron / open a door).
- It is **not** the mesh, the identity service, or an event-sourced domain app.
  No `reckon_db` / `evoq` / `macula` here — plain Phoenix + Ecto + Swoosh.
- Framing is the **position paper**'s: a commons, not a company. Copy says
  *commons / steward / federation / participation*, never *customer / product /
  market / exit*.

## Build & run

```bash
cd system
mix setup && mix phx.server      # http://localhost:4000
```
The landing page renders without a database. `mix ecto.create` needs Postgres.

## Full stack

`docker/dev/docker-compose.yml` — site + Postgres + Hanko (+ its own Postgres) +
Caddy. TLS is Caddy's job (automatic Let's Encrypt in prod, internal CA on
localhost in dev).

## Practices mirrored from macula-realm

| Concern | How |
|---------|-----|
| Auth | Self-hosted **Hanko** (passkey + email-OTP). `docker/hanko/config.yaml`, `HANKO_*` env. |
| Email | **Mailgun** HTTPS API via Swoosh. `BEAM_CAMPUS_MAILGUN_*` env, wired in `runtime.exs`. |
| TLS / proxy | **Caddy** + automatic Let's Encrypt. `docker/caddy/Caddyfile`. |
| Deploy | Release overlay `bin/start` (migrate → server). `Dockerfile.prod`. |
| CI | GitHub Actions (via Codeberg push-mirror) → Codeberg container registry. |

## House rules (this repo)

- **Codeberg is canonical** — push to `origin` (codeberg.org/beam-campus/…),
  never GitHub first. GitHub is the CI/registry mirror.
- **mix.exs leads, not the lock** — `mix.lock` is gitignored; deps resolve from
  `mix.exs` (`mix deps.get`, no `--frozen`).
- **Brand lives in `beam-campus-artwork`** — don't fork the theme; the daisyUI
  block in `app.css` is that repo's `tokens.css`. Update there, copy here.
- Vertical slicing if/when domain logic appears. No `services/`, `utils/`,
  `helpers/`. LiveViews own their own components.

## Key files

| File | Purpose |
|------|---------|
| `system/apps/beam_campus_web/lib/beam_campus_web/live/home_live.ex` | the landing page |
| `system/apps/beam_campus_web/assets/css/app.css` | BEAM Campus daisyUI theme + self-hosted font |
| `system/config/runtime.exs` | Mailgun + Hanko + prod endpoint |
| `system/apps/beam_campus/lib/beam_campus/release.ex` | migration task for the release |

## Not yet wired (see ROADMAP.md)

Hanko is scaffolded at the infra level (service + config + env + JWT config
keys) but there is **no members area / login flow yet**, and no `HankoJwt`
module. That is a deliberate future slice, not a stub — the site is public.
