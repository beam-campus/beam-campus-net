defmodule BeamCampus.Repo.Migrations.NoBredChampionEverCrossedTheMesh do
  @moduledoc """
  Erase the six recorded crossings that never happened.

  ⚠ THE CODE FIX COULD NOT REACH THESE ROWS, AND THAT IS BY DESIGN. The islands
  briefly published `champion_from => undefined` for a controller they bred
  themselves; an atom is a value, not an absence, so it crossed the wire as the
  string "undefined" and every locally bred champion was written down as having
  travelled. Both ends are fixed — the islands omit the key, and
  `Reign.came_from/1` normalises the string away — but neither touches what is
  already on disk, because `FollowTheChampions` widens a reign with
  `on_conflict: [set: [last_seen, sorties, score]]` and deliberately never
  rewrites `taken_from`. Where a reign came from is a fact about when it began,
  not something a later sighting may revise.

  So six rows would have gone on claiming a crossing for ever, on the one panel
  whose entire purpose is to show gene flow, and the first genuine crossing would
  have arrived indistinguishable from them.

  ⚠ AND "undefined" IS UNAMBIGUOUS. The build that wrote it published a real
  island id for a genuinely captured champion and the literal atom only for a
  bred one, so nulling this exact string discards no true crossing. Verified on
  the box before writing: all five islands report `sitter=bred`, and every row
  carrying the string sits beside one.
  """
  use Ecto.Migration

  def up do
    execute("UPDATE dronex_champions SET taken_from = NULL WHERE taken_from = 'undefined'")
  end

  # ⚠ IRREVERSIBLE ON PURPOSE. Rolling back would mean writing the lie back in,
  # and there is nothing to restore it from: the string carried no information
  # beyond "this island bred it", which the absent value now says correctly.
  def down, do: :ok
end
