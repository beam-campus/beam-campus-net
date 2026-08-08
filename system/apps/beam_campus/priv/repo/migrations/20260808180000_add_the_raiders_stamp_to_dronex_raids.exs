defmodule BeamCampus.Repo.Migrations.AddTheRaidersStampToDronexRaids do
  @moduledoc """
  The raider's half of the breeding stamp, which the read model was dropping.

  ⚠ A RAID ARRIVES IN TWO PIECES AND ONLY ONE WAS BEING KEPT. The defender
  publishes the RECORDING, which carries its own `rounds` and `generation`. Each
  side also publishes a COMMITMENT on acceptance, and the attacker's stamp exists
  nowhere else.

  `Dronex.RememberRaids` stored the recording alone, so every raid restored after
  a deploy came back with the defender's stamp and no attacker's.
  `WeighTheExperience` correctly refuses to read a missing stamp as a zero, so it
  excluded them: the panel went from about sixty points plotted to ONE, with 61
  of 64 marked unstamped, and it was the read model that did it rather than the
  fleet.
  """
  use Ecto.Migration

  def change do
    alter table(:dronex_raids) do
      add :attacker_rounds, :integer
      add :attacker_generation, :integer
    end
  end
end
