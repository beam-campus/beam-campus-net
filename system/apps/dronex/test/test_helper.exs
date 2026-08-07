ExUnit.start()

# The read-model tests write rows. The Repo belongs to :beam_campus, which this
# app depends on and which therefore starts with it; all that is left is to put
# the sandbox in manual mode, exactly as :biotope does for its own history tests.
Ecto.Adapters.SQL.Sandbox.mode(BeamCampus.Repo, :manual)
