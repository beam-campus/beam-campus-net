# CLAUDE.md — beam-campus-net

The public website for **BEAM Campus**, the research commons. Phoenix LiveView,
mirroring `macula-internal/macula-realm`'s operational practices.

## What this is (and is not)

- It **is** a content/landing site: the thesis, the substrate, the commons value
  theory, the three asks (run a node / patron / open a door).
- It is **not** the mesh, the identity service, or an event-sourced domain app.
  No `reckon_db` / `evoq` here, and no store.
- **It IS a mesh CONSUMER, as of 2026-07-31.** `macula` belongs here: the
  biotope, ASociety and DroneX spectators subscribe to published facts and render
  them. The rule until then said "no macula here", which was a blanket exclusion
  that had stopped being true, and a stale prohibition in a rules file is worse
  than none: the next session reads it and undoes the work. The constraint that
  actually matters is narrower and survives: **subscribe and render, never
  publish, never hold a store.** The site is a reader of the mesh, not a
  participant in it.
- ⚠ **AND NEVER REGENERATE.** The Robo Rumble spectator was removed on 2026-08-05
  for breaking exactly this. It received two genomes and a start index and
  **re-ran the duel locally**, which put a game engine inside a content website,
  pinned `apps/robo_rumbler` and the service on beam03 to commits whose
  fingerprints drifted with nothing comparing them, and made every viewer repeat
  about 1,900 frames of identical work. Raf's correction was *aggregate and
  visualize, never regenerate*. `apps/dronex` is the shape that replaces it: an
  island publishes a whole engagement as a RECORDING and the page animates it,
  which also buys scrub, pause and slow motion.
  **The rumbler service is still running on beam03. Only the page is gone.**
- Framing is the **position paper**'s: a commons, not a company. Copy says
  *commons / steward / federation / participation*, never *customer / product /
  market / exit*.

## Build & run

```bash
cd system
mix setup && mix phx.server      # http://localhost:4000
```
The landing page renders without a database.

⚠ **THE DATABASE IS SQLITE, NOT POSTGRES.** `BeamCampus.Repo` is
`Ecto.Adapters.SQLite3`: a file at `beam_campus_dev.db` in dev, `beam_campus_test*.db`
in test, and `/data/beam_campus.db` on a named volume in production. There is no
Postgres server for the site anywhere, so `mix ecto.create` needs nothing running.
This file previously said it needed Postgres, and that sentence sent a session
building a read model against an engine the site does not use.

## Full stack

`docker/dev/docker-compose.yml` — site + Hanko + `hanko-postgres` + Caddy. The
ONLY Postgres in that stack is Hanko's own, which Hanko requires and the site
never touches. Production runs no Postgres at all: site, Caddy, watchtower.

TLS is Caddy's job (automatic Let's Encrypt in prod, internal CA on localhost in
dev).

## Practices mirrored from macula-realm

| Concern | How |
|---------|-----|
| Auth | Self-hosted **Hanko** (passkey + email-OTP). `docker/hanko/config.yaml`, `HANKO_*` env. |
| Email | **Mailgun** HTTPS API via Swoosh. `BEAM_CAMPUS_MAILGUN_*` env, wired in `runtime.exs`. |
| TLS / proxy | **Caddy** + automatic Let's Encrypt. `docker/caddy/Caddyfile`. |
| Deploy | Release overlay `bin/start` (migrate → server). `Dockerfile.prod`. |
| CI | GitHub Actions on push to `main` → `ghcr.io/beam-campus/beam-campus-net` → watchtower on the box auto-pulls. |

## House rules (this repo)

- **GitHub is canonical** (since 2026-07-26) — push to the `github` remote
  (github.com/beam-campus/beam-campus-net), branch `main`. Do NOT push to
  Codeberg: that copy is soon to be deleted. `origin` still points at Codeberg
  in most clones, so check the full `git remote -v` and name the remote
  explicitly (`git push github main`) until origins are flipped.
  *Why the reversal:* Codeberg added Terms of Use § 2 (1) 7 by member vote on
  2026-07-22, banning projects that mostly consist of AI-generated code.
  The old push-mirror hop (Codeberg → GitHub) is gone; CI now runs directly on
  the canonical repo.
- **`mix format` cannot see a file you just created.** `apps/beam_campus_web/.formatter.exs`
  computes its `inputs` with `Path.wildcard` at load time so it can exclude one
  file, and Mix caches that list keyed on the config's mtime. A file added since
  the cache was built is invisible to BOTH `mix format` and
  `mix format --check-formatted`, so the gate passes locally and CI, which always
  builds cold, is the first thing to notice. It has cost three CI runs.

  Before pushing new files, do one of:

  ```bash
  touch apps/*/.formatter.exs && mix format    # invalidates the cache
  mix format path/to/new_file.ex               # explicit paths always work
  ```

  Verified by probe: a deliberately mis-formatted new file survives `mix format`
  untouched, and is fixed by either line above.
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
