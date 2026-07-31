defmodule RoboRumbler do
  @moduledoc """
  The site's window onto Robo Rumble: what has been seen, and how to watch it.

  One entry point, because the LiveView lives in another app and should not have
  to know that a board, a subscriber and a mesh holder exist.

  ## The site never publishes

  Every function here reads. Submitting a tank means publishing to the challenge
  topic, and that is deliberately not offered: a public web page that can inject
  work into a research service is a different thing with different consequences,
  and it is not what was asked for.

  ## A duel is watched by regenerating it, not by receiving it

  The rumbler publishes two genomes and a start index, about 1.2 KB. A visit is
  6,400 battles of roughly 200 turns, about 1.28 million frames and 93 MB. Because
  the engine is integer-deterministic, those 1.2 KB and those 93 MB say the same
  thing, so `replay/1` runs the fight here and gets the battle the rumbler counted
  on another machine, turn for turn. Verified across two machines and two OTP
  releases before any of this was built.
  """

  alias RoboRumbler.WatchRumbles
  alias RoboRumbler.WatchRumbles.Board

  @doc "Subscribe the caller to board changes: `{:rumble, kind}` messages."
  defdelegate subscribe(), to: WatchRumbles

  defdelegate field(), to: Board
  defdelegate visits(), to: Board
  defdelegate duels(), to: Board
  defdelegate fighting(), to: Board
  defdelegate empty?(), to: Board

  @doc "Whether the site is configured to read the mesh at all."
  def watching?, do: RoboRumbler.Mesh.configured?()

  @doc "Arena bounds in the engine's own fixed-point units. A viewer scales these."
  def arena, do: :robo_sim.arena_size()

  @doc """
  Regenerate a featured duel from its fact.

  Returns `{:ok, %{frames:, arena:, turns:, challenger:, winner:}}`, where
  `challenger` names which seat the visitor took. Frames carry positions,
  headings, energy, deaths and bullets in fixed point.

  Refuses rather than guesses: a fact missing a genome, or carrying one this
  engine will not accept, is an error the caller shows. A viewer that quietly
  substituted a default would draw a fight that never happened.

  ## It checks its own work

  The fact carries the turn count the rumbler measured on its machine. This app
  re-derives the placement from the start index, and that arithmetic lives in two
  codebases now, so it can drift. When the regenerated battle does not last
  exactly as long as the published one, this returns `:replay_mismatch` rather
  than frames. A viewer cannot tell a correct fight from a plausible one, so the
  check has to be here and not in anyone's eyes.
  """
  @spec replay(map()) :: {:ok, map()} | {:error, term()}
  def replay(%{} = fact) do
    with {:ok, challenger} <- genome(fact, "challenger_genome"),
         {:ok, resident} <- genome(fact, "resident_genome"),
         {:ok, placement} <- placement(fact),
         {:ok, seat} <- seat(fact) do
      seat
      |> seated(challenger, resident)
      |> run(placement, seat)
      |> agreed(Map.get(fact, "turns"))
    end
  end

  # ── Internals ───────────────────────────────────────────────────

  # Ids are `:first` and `:second`, matching the pairing the rumbler's own replay
  # test asserts against. Entrant list order is the placement order, so this is
  # the geometry as well as the label.
  defp run(entrants, placement, seat) do
    entrants
    |> :robo_rumble.replay(%{placement: placement})
    |> shaped(seat)
  end

  defp shaped({:ok, r}, seat) do
    {:ok,
     %{
       frames: Map.get(r, :frames),
       arena: arena(),
       turns: Map.get(r, :turns),
       winner: Map.get(r, :winner),
       challenger: seat
     }}
  end

  defp shaped({:error, _why} = e, _seat), do: e

  # No published turn count means an older fact; replay it and say so by omission
  # rather than refusing something this app simply cannot check.
  defp agreed(result, nil), do: result
  defp agreed({:ok, %{turns: t} = r}, t), do: {:ok, Map.put(r, :verified, true)}
  defp agreed({:ok, %{turns: got}}, want), do: {:error, {:replay_mismatch, want, got}}
  defp agreed({:error, _why} = e, _want), do: e

  defp seated(:first, challenger, resident),
    do: [{:first, {:genome, challenger}}, {:second, {:genome, resident}}]

  defp seated(:second, challenger, resident),
    do: [{:first, {:genome, resident}}, {:second, {:genome, challenger}}]

  defp genome(fact, key), do: unpack(Map.get(fact, key))

  defp unpack(nil), do: {:error, :genome_missing}

  defp unpack(b64) when is_binary(b64) do
    case Base.decode64(b64) do
      {:ok, bytes} -> :robo_genome.unpack(bytes)
      :error -> {:error, :genome_not_base64}
    end
  end

  # The published index is 1-based into the held-out split, which is the same
  # split the rumbler duels over. An index outside it is refused rather than
  # wrapped: a wrapped index is a different fight drawn under the right name.
  defp placement(fact), do: at(Map.get(fact, "start_index"), :robo_starts.split(:heldout))

  defp at(i, starts) when is_integer(i) and i >= 1 and i <= length(starts) do
    {ax, ay, ah, bx, by, bh} = Enum.at(starts, i - 1)
    {:ok, [{ax, ay, ah}, {bx, by, bh}]}
  end

  defp at(i, _starts), do: {:error, {:start_index_out_of_range, i}}

  defp seat(%{"challenger_seat" => "first"}), do: {:ok, :first}
  defp seat(%{"challenger_seat" => "second"}), do: {:ok, :second}
  defp seat(_fact), do: {:error, :challenger_seat_missing}
end
