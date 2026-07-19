import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :beam_campus, BeamCampus.Repo,
  database: Path.expand("../beam_campus_test#{System.get_env("MIX_TEST_PARTITION")}.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :beam_campus_web, BeamCampusWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Fr25z8WDccLYpW260jeeB3RH8JSbiBA1rwkXe1yCzYZ09+a2C9cR6cRa1r2i+bZm",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# In test we don't send emails
config :beam_campus, BeamCampus.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
