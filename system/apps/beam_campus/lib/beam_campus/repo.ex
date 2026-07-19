defmodule BeamCampus.Repo do
  use Ecto.Repo,
    otp_app: :beam_campus,
    adapter: Ecto.Adapters.SQLite3
end
