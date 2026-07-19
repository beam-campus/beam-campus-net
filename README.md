# beam-campus-net

The website for **BEAM Campus** — a European research commons for sovereign,
distributed and evolutionary AI.

A Phoenix LiveView site, built to mirror the operational practices of
`macula-internal/macula-realm`: self-hosted **Hanko** auth, **Mailgun** over
HTTPS, **Caddy** with automatic Let's Encrypt, a release-overlay deploy, and CI
that publishes an image to the Codeberg container registry.

## Layout

```
beam-campus-net/
├── system/                     # the Phoenix umbrella
│   ├── apps/
│   │   ├── beam_campus/         # core (Repo, Mailer, Release)
│   │   └── beam_campus_web/     # Phoenix — HomeLive landing, brand theme
│   ├── config/                 # config, dev, prod, runtime
│   └── rel/overlays/bin/       # migrate · server · start
├── docker/
│   ├── dev/docker-compose.yml  # site + postgres + hanko(+db) + caddy
│   ├── caddy/Caddyfile         # reverse proxy + automatic HTTPS
│   └── hanko/config.yaml       # self-hosted auth (mirror of realm)
├── Dockerfile.prod             # multi-stage release image
└── .github/workflows/          # CI + Codeberg image publish
```

## Develop

```bash
cd system
mix setup                 # deps + assets
mix ecto.create           # needs Postgres on localhost:5432
mix phx.server            # http://localhost:4000
```

No database running? The landing page still renders — it does not query the DB.

## Full stack (Docker)

```bash
cd docker/dev
cp .env.example .env      # add Mailgun keys if you want email
docker compose up -d --build
# site:   https://localhost:8443  (Caddy, self-signed in dev)
#         http://localhost:4000   (direct)
# hanko:  http://localhost:8000
```

## Brand

Theme, logo, favicon and the self-hosted Hanken Grotesk font come from
`beam-campus/beam-campus-artwork`. The daisyUI theme in
`system/apps/beam_campus_web/assets/css/app.css` is that repo's `tokens.css`.

## Deploy

CI builds `Dockerfile.prod` and pushes to
`codeberg.org/beam-campus/beam-campus-net` (tags → `:latest` + semver; `main` →
`:main` + `:<sha>`). The container runs `bin/start`, which migrates then boots.
Set `PHX_HOST`, `SECRET_KEY_BASE`, `DATABASE_URL`, the `BEAM_CAMPUS_MAILGUN_*`
and `HANKO_*` env, and (for Caddy) `SITE_ADDRESS` + `ACME_EMAIL`.

## License

Code: AGPL-3.0 (the commons instrument). Brand marks: held in stewardship —
see `beam-campus-artwork`.
