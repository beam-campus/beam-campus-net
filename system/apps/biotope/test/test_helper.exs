ExUnit.start()

# The history tests write rows. The Repo belongs to :beam_campus, which this app
# depends on and which therefore starts with it; all that is left is to put the
# sandbox in manual mode, exactly as :beam_campus does for its own tests.
Ecto.Adapters.SQL.Sandbox.mode(BeamCampus.Repo, :manual)
