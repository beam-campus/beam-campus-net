import Config

# config/runtime.exs is executed for all environments, including during
# releases. It runs after compilation and before the system starts, so it
# is where production configuration and secrets are read from the
# environment. Do not put compile-time config here.
#
# Mirrors macula-realm's operational practices: Mailgun (HTTPS API, since
# Linode/Hetzner block outbound SMTP), self-hosted Hanko, TLS terminated by
# Caddy in front of the release.

# ── Robo Rumble spectator (all environments when configured) ─────────────
# The site READS the mesh: it subscribes to the rumbler's facts and renders them.
# It never publishes and holds no store.
#
# THE REALM IS PUBLIC AND SO IS ITS NAME. Rumble facts do not ride the Hecate
# fleet realm; they have their own, `net.beamcampus.rumble`, precisely so that a
# public web container never holds the tag that routes sentinel sightings and
# warden facts. A realm id is sha256 of its name, so this tag is derived rather
# than issued, and stating it openly is the point rather than a leak.
#
# The SEEDS have no default, though. Naming a public realm costs nothing; dialling
# a production station from every dev clone does. Unset seeds means the site boots
# normally, connects to nothing, and the workbench page shows its empty state.
config :robo_rumbler,
  realm:
    System.get_env("BEAM_CAMPUS_RUMBLE_REALM") ||
      "0a346d25957755075dabefcc88e03c050df86ce3b7dc5a5a63ff38f32462c352",
  namespace: System.get_env("BEAM_CAMPUS_RUMBLE_NS") || "rumble-scratch",
  seeds:
    System.get_env("BEAM_CAMPUS_RUMBLE_SEEDS", "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)

# ── Mailgun (all environments when the key is present) ────────────────────
# Enables real email in dev too, for testing the contact path.
if System.get_env("BEAM_CAMPUS_MAILGUN_API_KEY") do
  config :beam_campus, BeamCampus.Mailer,
    adapter: Swoosh.Adapters.Mailgun,
    api_key: System.get_env("BEAM_CAMPUS_MAILGUN_API_KEY"),
    domain: System.get_env("BEAM_CAMPUS_MAILGUN_DOMAIN"),
    base_url: System.get_env("BEAM_CAMPUS_MAILGUN_BASE_URL", "https://api.eu.mailgun.net")

  config :swoosh, :api_client, Swoosh.ApiClient.Req
end

# Contact recipient for enquiries (patron / open-a-door).
if contact_email = System.get_env("BEAM_CAMPUS_CONTACT_EMAIL") do
  config :beam_campus, :contact_email, contact_email
end

# Admin users, by email (comma-separated). Reserved for a future members area.
if admin_emails = System.get_env("BEAM_CAMPUS_ADMIN_EMAILS") do
  emails = admin_emails |> String.split(",") |> Enum.map(&String.trim/1)
  config :beam_campus, :admin_emails, emails
end

# ── Hanko (self-hosted auth) — env overrides for the public URLs ──────────
if hanko_url = System.get_env("HANKO_API_URL") do
  config :beam_campus_web, :hanko_api_url, hanko_url
end

if jwks_url = System.get_env("HANKO_JWKS_URL") do
  existing = Application.get_env(:beam_campus_web, BeamCampusWeb.HankoJwt, [])
  config :beam_campus_web, BeamCampusWeb.HankoJwt, Keyword.put(existing, :jwks_url, jwks_url)
end

if hanko_issuer = System.get_env("HANKO_ISSUER") do
  existing = Application.get_env(:beam_campus_web, BeamCampusWeb.HankoJwt, [])
  config :beam_campus_web, BeamCampusWeb.HankoJwt, Keyword.put(existing, :issuer, hanko_issuer)
end

# ── Dev overrides for Docker (SQLite path / PORT) ─────────────────────────
if config_env() == :dev do
  if db_path = System.get_env("BEAM_CAMPUS_DB_PATH") do
    config :beam_campus, BeamCampus.Repo, database: db_path
  end

  if port = System.get_env("PORT") do
    config :beam_campus_web, BeamCampusWeb.Endpoint,
      http: [ip: {0, 0, 0, 0}, port: String.to_integer(port)],
      server: true
  end
end

# ── Production runtime configuration ──────────────────────────────────────
if config_env() == :prod do
  # SQLite: a single file on a mounted volume. WAL + a busy timeout keep the
  # web workers from tripping over each other on the single writer.
  database_path = System.get_env("BEAM_CAMPUS_DB_PATH") || "/data/beam_campus.db"

  config :beam_campus, BeamCampus.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5"),
    journal_mode: :wal,
    busy_timeout: 5_000

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "beam-campus.net"

  config :beam_campus_web, BeamCampusWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base,
    server: true,
    # "//" prefix = scheme-agnostic; works behind Caddy's TLS termination.
    check_origin: ["//#{host}", "//www.#{host}"]

  config :beam_campus, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")
end
