defmodule Dronex.SayWhoWon do
  @moduledoc """
  The two words a stranger reads, in one place.

  ## Why this exists

  The page had three vocabularies for the same two sides and used all three at
  once. The wire says `attacker` and `defender`. The experience lanes said
  "raider" and "island". The duration histogram said "raider won" and "island
  held". The replay header said "won by attacker".

  A visitor is asked to work out that the raider, the attacker and the row of the
  ledger are the same thing, and that the island, the defender and the column are
  too. That is a puzzle nobody set deliberately: each of those strings was
  written in a different file on a different day and each was reasonable alone.

  ## ⚠ THE WIRE KEEPS ITS OWN WORDS

  `attacker` and `defender` are what the island publishes and they are not
  changing: they key the fact, the ledger pairs and the side colours. This
  translates them at the very edge, for display, and nothing upstream of a
  template should call it.

  ## ⚠⚠ RAIDER AND ISLAND, AND THE ASYMMETRY IS DELIBERATE

  Not "raider and defender", not "attacker and island". A raid is a thing one
  side DOES and a place the other side IS. An island is an island whether or not
  anybody is attacking it today, and the same island is a raider tomorrow when it
  sends a swarm out. Naming the pair for the act and the place says that; naming
  it for two symmetrical roles would imply a permanent allegiance the data model
  explicitly refuses.
  """

  @doc """
  What to print for an outcome: "raider won", "island held" or "drawn".

  ⚠ AN UNKNOWN OUTCOME IS A DRAW, NOT A CRASH. This reads a value off a public
  realm, and a later island may publish a word this one has never heard of. The
  page saying "drawn" about something it does not understand is better than the
  page not rendering.
  """
  @spec said(binary() | nil) :: binary()
  def said("attacker"), do: "raider won"
  def said("defender"), do: "island held"
  def said(_drawn), do: "drawn"

  @doc """
  Which side an outcome belongs to, for the colour convention.

  Returns the wire word, normalised, so `--side-<role>` resolves. Kept beside
  `said/1` so the phrase and its colour cannot drift apart, which is exactly what
  happened when they lived in three files.
  """
  @spec role(binary() | nil) :: binary()
  def role("attacker"), do: "attacker"
  def role("defender"), do: "defender"
  def role(_drawn), do: "draw"

  @doc "The three outcomes in the order a reader should meet them, raider first."
  @spec every() :: [{binary(), binary(), binary()}]
  def every do
    for w <- ["attacker", "draw", "defender"], do: {w, said(w), role(w)}
  end
end
