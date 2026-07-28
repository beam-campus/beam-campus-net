# beam-campus-net — Roadmap

## Done — scaffold

- Phoenix 1.8 umbrella (`beam_campus` + `beam_campus_web`), Elixir 1.18 / OTP 27.
- BEAM Campus brand: daisyUI dark+light theme, self-hosted Hanken Grotesk
  (woff2), logo / favicon, `HomeLive` landing (thesis, substrate, commons value
  theory, the three asks).
- Operational stack mirrored from macula-realm: `Dockerfile.prod` + release
  overlay (`bin/start` → migrate → server), dev `docker-compose` (site +
  Postgres + Hanko + Caddy), Mailgun in `runtime.exs`, Caddy with automatic
  Let's Encrypt, CI (compile/format/test) + ghcr.io image publish.
- `/health` endpoint. Verified: compiles clean, assets build, `/` renders,
  `/health` returns 200.

## Next — decisions to confirm

- [ ] **Domain.** `beam-campus.net` is a placeholder throughout (runtime.exs,
      Caddyfile, Hanko origins, mail domain). Confirm the real domain and sweep.
- [x] **Registry.** Resolved. CI publishes to
      `ghcr.io/beam-campus/beam-campus-net`, the package is public so the box
      pulls anonymously, and watchtower auto-pulls. The push-mirror question is
      moot: GitHub became canonical on 2026-07-26, so CI runs on the canonical
      repo and there is no mirror hop.
- [ ] **Mailgun.** EU region assumed (`api.eu.mailgun.net`). Create the sending
      domain + API key, put them in the deploy secrets.

## Next — build

- [ ] **Contact / enquiry slice.** A LiveView form for the three asks that sends
      via `BeamCampus.Mailer` to `:contact_email`. (Mailer is wired; the form is
      not built yet.)
- [ ] **Members area + Hanko login.** Hanko runs and issues JWTs, but nothing
      consumes them yet. Build: `HankoJwt` verifier, the `<hanko-auth>` LiveView,
      a local `users` upsert keyed on Hanko `sub`, session issuance, the
      `email.send` webhook → Mailgun. Mirror macula-realm's flow.
- [ ] **Content.** Node-running guide, patron page, links to the substrate repos
      and hex packages, published research.
- [ ] **`robots.txt` / sitemap / OG tags** for the real domain.

## Later

- [ ] Trademark/attribution footer page (AGPL + marks in stewardship).
- [ ] i18n — NL / FR / DE first (European commons).
