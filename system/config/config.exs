# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure Mix tasks and generators
config :beam_campus,
  ecto_repos: [BeamCampus.Repo]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :beam_campus, BeamCampus.Mailer, adapter: Swoosh.Adapters.Local

# Where "become a patron / open a door" enquiries are sent. Override with
# BEAM_CAMPUS_CONTACT_EMAIL in runtime.exs.
config :beam_campus, :contact_email, "raf.lefever@erlef.org"

# Hanko self-hosted auth (passkey + email-OTP), mirroring macula-realm.
# Consumed by the browser <hanko-auth> component and server-side JWT
# validation. Real endpoints arrive via HANKO_* env in runtime.exs; the
# defaults below are the local-dev Hanko. Auth is scaffolded, not yet wired
# into a members area — see ROADMAP.md.
config :beam_campus_web, :hanko_api_url, "http://localhost:8000"

config :beam_campus_web, BeamCampusWeb.HankoJwt,
  jwks_url: "http://localhost:8000/.well-known/jwks.json",
  issuer: "http://localhost:8000"

config :beam_campus_web,
  ecto_repos: [BeamCampus.Repo],
  generators: [context_app: :beam_campus]

# Configures the endpoint
config :beam_campus_web, BeamCampusWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BeamCampusWeb.ErrorHTML, json: BeamCampusWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BeamCampus.PubSub,
  live_view: [signing_salt: "5rAr6Im9"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  beam_campus_web: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../apps/beam_campus_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  beam_campus_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/beam_campus_web", __DIR__)
  ]

# In the container build the esbuild/tailwind binaries are pre-fetched with
# curl by Dockerfile.prod and pointed at via these env vars — GitHub
# release-assets / npm serve a cert OTP's httpc rejects from some CDN POPs, so
# the packages' own downloader fails there. Unset locally → normal download.
if p = System.get_env("TAILWIND_PATH"), do: config(:tailwind, path: p)
if p = System.get_env("ESBUILD_PATH"), do: config(:esbuild, path: p)

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# faber-tweann: use the pure-Erlang forward pass, never load the Rust NIF (the
# adaptation demo only does inference). Pairs with FABER_TWEANN_SKIP_NIF=1 at build.
config :faber_tweann, nif_impl: :fallback

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
