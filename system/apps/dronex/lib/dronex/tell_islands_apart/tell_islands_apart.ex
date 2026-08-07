defmodule Dronex.TellIslandsApart do
  @moduledoc """
  A name is not an identity, so a name is never shown alone.

  ## The whole problem in one sentence

  Every island name on this page is **a string somebody typed about themselves**,
  and until now nothing beside it distinguished two people who typed the same one.

  `dronex_identity` in the island service says so in its own header, and it was
  ported from the biotope sibling where the lesson was "learned rather than
  designed":

  > AND IT IS NOT ONLY AN ACCIDENT. Anyone may type your island's name into their
  > own config and begin collecting your sorties.

  ## What was already right, and what was not

  The data model honours the split. Every row on the board is keyed on
  `island_id`, the ledger keys pairs on `{attacker_id, island_id}`, and the fleet
  fold counts by id. **Two strangers both calling themselves `beam01` are already
  two rows, two cells and two leaderboard entries.** Nothing merges.

  The RENDERING collapsed them. Nothing on the page ever showed an id, so those
  two correct, separate rows were byte-identical on screen and a reader saw one
  island contradicting itself.

  ## Always, not only when ambiguous

  Showing the mark only when two labels collide is prettier and is the wrong
  choice twice over. It fails exactly when it matters, because a stranger taking
  the name of an island that is currently offline produces no visible collision
  at all. And it teaches the reader that a bare name means "verified unique",
  which is a promise nothing here can keep.

  So the mark is always there. The id is the identity; the name is a nickname.

  ## ⚠ WHAT THIS DOES NOT FIX

  Ids are published in every fact, so a stranger can copy one. Two islands
  sharing an id genuinely merge into one board row flickering between two
  rosters, and no amount of rendering touches that. It is the `Trust` item owed
  in the island service's `CHARTER.md`, and it needs a signed identity.

  What the mark changes is the CHARACTER of the attack. Typing a name is free,
  silent and deniable. Copying an id produces one island visibly disagreeing with
  itself. This does not prevent impersonation; it moves it from invisible to
  conspicuous, which is the part presentation can honestly do.
  """

  # Four hex characters of a 32-character id. Sixteen bits, which for an
  # archipelago of tens of islands is collision-free in practice, and two
  # islands that DO share the first four are worth a second look anyway.
  @mark_length 4

  @doc """
  The short mark for an id: the first four characters, git-style.

  Nil for anything that is not an id, so a caller renders nothing rather than
  the word "nil".
  """
  @spec mark(binary() | nil) :: binary() | nil
  def mark(id) when is_binary(id) and byte_size(id) >= @mark_length,
    do: String.slice(id, 0, @mark_length)

  def mark(_absent), do: nil

  @doc """
  A row's name and its mark, ready to render as two separate things.

  Returns `{name, mark}`. The mark is nil when there is nothing to add:

  - an island that has not published a name yet is ALREADY shown by its id, and
    `{id, "a6b1"}` would print the mark twice
  - an id too short to be one
  """
  @spec named(map() | nil) :: {binary(), binary() | nil}
  def named(nil), do: {"somebody", nil}

  def named(%{id: id} = row) do
    name = Dronex.label(row)
    apart(name, id, mark(id))
  end

  def named(%{} = row), do: {Dronex.label(row), nil}

  # The label fell back to the id, so the id is already on screen.
  defp apart(name, id, _mark) when name == id, do: {short(id), nil}
  defp apart(name, _id, mark), do: {name, mark}

  # A bare id is unreadable at full length and is not the common case, so it gets
  # a longer slice than the mark: it is standing in for a name, not qualifying one.
  defp short(id), do: String.slice(id, 0, 8)

  @doc """
  One string, for a `title`, an `aria-label`, or anywhere markup cannot go.

  Spoken rather than punctuated: a screen reader should say "beam01 a6b1", not
  "beam01 middle dot a6b1".
  """
  @spec spoken(map() | nil) :: binary()
  def spoken(row), do: row |> named() |> joined()

  defp joined({name, nil}), do: name
  defp joined({name, mark}), do: "#{name} #{mark}"

  @doc """
  The same, from a bare id, for a fact that carries an id and no row.

  A raid fact ships `attacker_id` with no attacker name, so the name has to be
  looked up on the board and the island may not be there at all.
  """
  @spec spoken_id(binary() | nil) :: binary()
  def spoken_id(nil), do: "somebody"
  def spoken_id(id), do: id |> Dronex.island() |> or_bare(id)

  defp or_bare(nil, id), do: short(id)
  defp or_bare(row, _id), do: spoken(row)
end
