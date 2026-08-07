defmodule Dronex.WatchBouts.Board do
  @moduledoc """
  One ETS row per island: its vitals, and the last bout it published.

  ## Filed under identity, never under name

  An island's name is an environment variable falling back to a hostname, and two
  islands can carry the same one. `hecate-dronex` mints 128 bits into its data
  directory precisely so that a reader has something to file under that nobody
  types. Filed under the name, two islands called `beam01` would overwrite each
  other and the page would show one place flickering between two rosters.

  ⚠ **Identity defeats accident and not impersonation.** Nothing signs the id, so
  a node could copy another's. This board is a reader: it shows what arrived and
  attributes it to whoever claimed it, which is the honest limit.

  ## The last bout only, and that is not a shortcut

  A bout is a RECORDING of a whole engagement — **measured at 1.2 MB on the box,
  not the "tens of kilobytes" this paragraph claimed until 2026-08-06** — and it
  is about a moment. Keeping a history of them in memory would be writing a video
  into ETS. What is worth keeping over time is the vitals, and those belong in a
  read model with a schema if they are ever wanted, which is not this.

  The wrong figure here was not decoration. It is what made a 64-row cap sound
  cheap, and the cap was the only thing standing between a public topic and the
  node's memory. A size assumption in a comment earns a measurement.

  ## Bounded, and it says when it refuses

  A public realm is writable by anyone who can reach a station, so an unbounded
  table is an unbounded memory leak with a stranger holding the tap. The board
  caps the islands it will hold and counts what it turned away, and the page
  shows a non-zero count rather than quietly lying about how many islands exist.

  ## Raids are filed under the RAID, not under an island

  A raid is the only fact here that is about **two** islands. Both sides publish
  a commitment naming the same `raid_id`, and the defender publishes the
  recording. Filed under the publisher, the attacker's half of the story would
  have no home and a raid in flight would look like two unrelated events.

  So raids live under `{:raid, raid_id}` and carry whatever has arrived so far:
  one commitment, then usually the other, then the recording when the fight ends.
  A raid with one commitment and no recording is one in flight — or one whose
  defender went dark, which is the same shape, and is exactly why both sides
  emit one.

  Islands are few and long-lived; raids are many and are moments, so they are
  capped separately and the oldest go first.

  ## ⚠ THE FRAMES LIVE IN A SEPARATE TABLE, AND THAT IS WHY THE SITE IS UP

  This module used to keep each recording's frames inside the row, and it killed
  the site every two hours. The measurement, taken on the box on 2026-08-06:

    * one raid recording is **118 frames and 1.2 MB** — the doc above said "tens
      of kilobytes", and was wrong by a factor of about forty;
    * at the 64-raid cap the table therefore reached **121 MB**;
    * every read of it went through `:ets.tab2list/1`, which copies the WHOLE
      table into the calling process;
    * the page's `load/1` did that six to eight times per redraw, twice a second,
      per viewer, and `evict_oldest_raids/0` did it again on every arriving raid.

  So a 1.9 GB box ran a BEAM that wanted 6.9 GB, and the kernel shot it. The
  frames were never what the readers wanted: `islands/0`, `raids/0`,
  `watchable/0` and `leaderboard/0` read scalars — a winner, a tick count, who
  fought whom — and the megabyte of positions rode along in every copy.

  So the mass is stored apart, under the same `{kind, id}` key the ranking
  already uses, and it is fetched by single-key lookup for the ONE fight being
  drawn. The rows carry `frame_count` so a reader can still say how long a
  recording is without holding it.

  ## The recordings are capped in BYTES, not in count

  A cap of "sixty-four recordings" is not a cap: the items are published by
  anyone who can reach a public station, and a longer fight is a bigger item, so
  a count bound is an unbounded number of megabytes wearing a bound's clothes.
  This holds a byte budget and drops the oldest until it fits, and refuses a
  single recording far larger than any real one outright.

  A fight whose recording has been dropped KEEPS ITS ROW — the scoreline is a
  fact, it is cheap, and the map's arcs and the counts are built from it. What it
  loses is its place in `Dronex.watchable/0`, which is the list of fights the
  page offers to PLAY.

  ⚠ **THIS PARAGRAPH SAID THE OPPOSITE UNTIL A FIFTH ISLAND JOINED**, and the
  difference was not academic. It claimed a dropped fight should still be ranked,
  on the reasoning that a scoreline is worth showing. That is true of the map and
  false of a watch-list: measured with five islands raiding, the page ranked 69
  fights and held 29 recordings, so 40 of them drew nothing and whichever
  unplayable one scored highest became the default view. A blank canvas reads as
  a broken site, not as an old fight.

  `recording/1` still answers `:gone` and the player still says so, because a
  recording can age out between being listed and being clicked. That is now the
  rare backstop it was always meant to be rather than the common case.
  """

  @table :dronex_board
  @recordings :dronex_recordings
  @history :dronex_history

  @max_islands 64
  @max_raids 64

  # ⚠ SMALL AGAIN, AND ON PURPOSE. This was 128 MB so that all 64 ranked fights
  # stayed playable. That budget existed to serve an ANIMATION, and the animation
  # was the most expensive thing on the site by a factor of about three thousand:
  # 128 MB of frames against 33 KB of board and 5 KB of history, for a picture of
  # an outcome that is a coin flip.
  #
  # What the frames are actually FOR is the two analyses — where the damage came
  # from, and what the towers held. Those now run once, HERE, when a recording
  # arrives, and what survives is about twenty integers on the raid row. The
  # frames are then worth keeping only for the handful of fights somebody might
  # actually press play on.
  #
  # ⚠⚠ AND THE ANALYSES GOT STRONGER BY SHRINKING. Computed per selected fight
  # they described n=1. Computed at ingest they accumulate over every raid the
  # board has ever seen, so the page can print a distribution with its n on it.
  #
  # The old note, kept because the coupling it describes is still real:
  #
  # ⚠ THIS MUST COVER A FULL BOARD, AND AT 48 MB IT DID NOT.
  #
  # The row cap and this budget were set independently on 2026-08-06 and they
  # disagreed. Measured hours later, with a fifth island raiding: 64 raid rows
  # listed, 29 recordings held, 45 MB of a 48 MB budget — so the page offered 69
  # fights and could draw 29 of them. "Listed but blank" was not the graceful
  # edge the doc below describes, it was 58% of the exhibit.
  #
  # The arithmetic, so the next person changing @max_raids sees the coupling:
  #
  #     64 rows  x  ~1.6 MB measured per recording  =  ~102 MB
  #
  # 128 MB therefore holds a full board with headroom for recordings that run
  # long. It is affordable because these are HELD and never copied — that was
  # the whole point of splitting them out — and the site container is capped at
  # 1.4 GB while sitting near 290 MB.
  #
  # The budget still does real work: @max_recording allows 8 MB apiece, so a
  # pathological board would be 512 MB without it.
  @budget 8 * 1024 * 1024

  # No real recording approaches this. One that does is a publisher fault or a
  # stranger, and either way it is not going in.
  @max_recording 8 * 1024 * 1024

  # ⚠ NOTHING RECORDED A TIME SERIES UNTIL NOW, and that absence is why the most
  # interesting thing this exhibit has produced could not be read. beam03 sat
  # 288/288 on the frozen exam one morning and 1/288 nine hours later, and the
  # only reason anybody knows is that two snapshots happened to be taken by hand.
  # A page that draws counters and no trajectory can show that a number is odd
  # and never that it MOVED.
  #
  # So the board keeps a little history, and the shape of it is chosen to stay
  # cheap: SCALARS ONLY, one sample per island per @sample_every_ms, and a hard
  # cap per island. Vitals arrive every second from every island; sampling them
  # all would be a leak with a clock on it.
  #
  # ⚠⚠ AND IT IS MEMORY, NOT A STORE. It starts empty on every restart and says
  # so where it is drawn. The alternative is a schema and a disk, which this site
  # deliberately does not have — it is a reader of the mesh and holds no store.
  @sample_every_ms 30_000
  @max_samples 240

  # A raid takes two commitments and one recording. More than this arriving under
  # one raid id is a republishing loop or somebody filling the table, and the
  # list it appends to has no other bound.
  @max_parts 4

  @doc "Create the tables. Idempotent, so a subscriber restart does not lose the board."
  def init do
    ensure(@table, fn -> :ets.insert(@table, {:refused, 0}) end)
    ensure(@recordings, fn -> :ok end)
    ensure(@history, fn -> :ok end)
    :ok
  end

  defp ensure(name, seed) do
    case :ets.whereis(name) do
      :undefined ->
        :ets.new(name, [:named_table, :public, :set, read_concurrency: true])
        seed.()
        :ok

      _ref ->
        :ok
    end
  end

  @doc "File one fact against an island, keyed by the kind of topic it arrived on."
  @spec put(binary(), atom(), map()) :: :ok
  def put(key, kind, fact) when is_binary(key) and is_atom(kind) and is_map(fact) do
    row = existing(key) || fresh(key)
    accept(room_for?(key), key, kind, fact, row)
  end

  defp accept(false, _key, _kind, _fact, _row), do: refuse()

  defp accept(true, key, kind, fact, row) do
    light = stow({kind, key}, fact)

    updated = %{
      row
      | name: Map.get(light, "island", row.name),
        facts: Map.put(row.facts, kind, light),
        last_seen: System.system_time(:millisecond)
    }

    :ets.insert(@table, {key, updated})
    sampled(kind, key, light)
    :ok
  end

  # ── History ─────────────────────────────────────────────────────

  @doc """
  What this island's numbers have been doing, oldest first.

  Empty until the second sample: one point is not a trajectory and a chart of it
  would be a dot pretending to be a line.
  """
  @spec history(binary()) :: [map()]
  def history(id) do
    case :ets.lookup(@history, id) do
      [{^id, samples}] -> Enum.reverse(samples)
      [] -> []
    end
  end

  @doc "How often the board takes a sample, so a reader can label the axis."
  @spec sample_every_ms() :: pos_integer()
  def sample_every_ms, do: @sample_every_ms

  @doc """
  The frozen exam as a percentage, from a vitals fact.

  ⚠ ONE PLACE, because the leaderboard and the history chart must not be able to
  disagree about what an island scored. They are the same number drawn twice.
  """
  @spec exam_score(map()) :: non_neg_integer()
  def exam_score(vitals) when is_map(vitals) do
    rungs = length(Map.get(vitals, "benchmark_rungs", []))
    starts = Map.get(vitals, "benchmark_starts", 0)
    wins = Map.get(vitals, "benchmark_wins", [])
    scored(is_list(wins) && Enum.sum(wins), rungs * starts)
  end

  def exam_score(_absent), do: 0

  defp scored(_wins, 0), do: 0
  defp scored(false, _n), do: 0
  defp scored(wins, n), do: div(wins * 100, n)

  # Only vitals carry the numbers a trajectory is made of, and only every
  # @sample_every_ms — they arrive once a second from every island.
  defp sampled(:vitals, id, fact), do: keep(id, :ets.lookup(@history, id), fact)
  defp sampled(_other, _id, _fact), do: :ok

  defp keep(id, [{_id, [%{at: at} | _] = samples}], fact) do
    now = System.system_time(:millisecond)
    store(now - at >= @sample_every_ms, id, samples, fact, now)
  end

  defp keep(id, _none, fact), do: store(true, id, [], fact, System.system_time(:millisecond))

  defp store(false, _id, _samples, _fact, _now), do: :ok

  defp store(true, id, samples, fact, now) do
    point = %{
      at: now,
      score: exam_score(fact),
      roster: Map.get(fact, "roster", 0),
      generation: Map.get(fact, "generation", 0),
      rounds: Map.get(fact, "rounds", 0),
      captures: Map.get(fact, "captures", 0)
    }

    :ets.insert(@history, {id, Enum.take([point | samples], @max_samples)})
    :ok
  end

  defp refuse do
    :ets.update_counter(@table, :refused, {2, 1}, {:refused, 0})
    :ok
  end

  defp room_for?(key), do: existing(key) != nil or map_size(rows()) < @max_islands

  @doc """
  File a commitment or a recording against the raid it names.

  Merged rather than replaced: the attacker's commitment, the defender's
  commitment and the recording arrive separately and none of them is complete on
  its own.
  """
  @spec put_raid(binary(), atom(), map()) :: :ok
  def put_raid(raid_id, kind, fact) when is_binary(raid_id) and is_atom(kind) do
    key = {:raid, raid_id}
    row = existing(key) || %{id: raid_id, parts: %{}, readings: %{}, last_seen: nil}
    # ⚠ READ THE FRAMES BEFORE `stow/2` TAKES THEM AWAY. This is the only moment
    # they are in hand: after the split they belong to a byte budget that will
    # evict them, and a recording evicted before it was read is a fight nobody
    # can ever account for.
    read = readings(kind, Map.get(fact, "frames"))
    light = stow({kind, raid_id}, fact)

    :ets.insert(
      @table,
      {key,
       %{
         row
         | parts: Map.update(row.parts, kind, [light], &newest([light | &1])),
           readings: Map.merge(Map.get(row, :readings, %{}), read),
           last_seen: System.system_time(:millisecond)
       }}
    )

    evict_oldest_raids()
    :ok
  end

  # ⚠ ONCE, AT INGEST, AND NEVER AGAIN. Walking 120 frames of 24 drones is cheap
  # once per raid and wasteful per render, and the frames will not survive to be
  # walked later anyway.
  defp readings(:raid, [%{} | _] = frames) do
    %{
      losses: Dronex.AccountForLosses.account(frames),
      coverage: Dronex.SeeWhatTheTowersSaw.coverage(frames)
    }
  rescue
    # ⚠ A MALFORMED RECORDING COSTS ITS OWN READING AND NOTHING ELSE. These
    # frames arrive on a PUBLIC realm, so the shape is whatever a stranger sends,
    # and an island one version ahead is the ordinary case rather than the
    # adversarial one. Before this clause a single unexpected frame took the
    # whole `put_raid/3` down and with it every fact in that delivery.
    _malformed -> %{}
  end

  # Not a recording, or frames in a shape this cannot read.
  defp readings(_kind, _absent), do: %{}

  @doc """
  What was measured from every raid this board has seen, folded together.

  ⚠ THE `n` IS RETURNED WITH IT, ALWAYS. These are accumulations over whatever
  raids happened to arrive and survive the row cap — a rolling window, not a
  sample anybody chose — so a reader who cannot see how many fights are behind a
  percentage is being invited to trust it.
  """
  @spec readings() :: %{losses: list(), coverage: list(), n: non_neg_integer()}
  def readings do
    taken = for r <- raids(), map_size(Map.get(r, :readings, %{})) > 0, do: r.readings

    %{
      losses: Enum.map(taken, & &1.losses),
      coverage: Enum.map(taken, & &1.coverage),
      n: length(taken)
    }
  end

  # ⚠ THIS LIST HAD NO BOUND. Two commitments and one recording is the whole of a
  # raid, so a republishing island — or anyone who can reach a public station —
  # could append under one raid id until the node died, inside a table whose
  # ROW count was capped and whose row SIZE was not.
  defp newest(parts), do: Enum.take(parts, @max_parts)

  @doc """
  The frames of one fight, or `:gone` if the budget dropped it.

  Keyed by the `{kind, id}` the ranking hands out, so a page that has an entry
  can ask for its recording without knowing where the mass is kept.
  """
  @spec recording({atom(), binary()}) :: {:ok, list()} | :gone
  def recording(key) do
    case :ets.lookup(@recordings, key) do
      [{^key, _at, _bytes, frames}] -> {:ok, frames}
      [] -> :gone
    end
  end

  @doc """
  The byte budget for held recordings, and the per-recording ceiling.

  Exported so the coupling with `@max_raids` can be asserted rather than
  remembered: a board that LISTS n fights must be able to HOLD n recordings, and
  when those two numbers were set independently the page ended up offering 69
  fights and drawing 29.
  """
  @spec budget_bytes() :: pos_integer()
  def budget_bytes, do: @budget

  @spec max_recording_bytes() :: pos_integer()
  def max_recording_bytes, do: @max_recording

  @spec max_raids() :: pos_integer()
  def max_raids, do: @max_raids

  @doc """
  Whether a fight's frames are still held.

  ⚠ USE THIS TO ASK, NEVER `recording/1`. A lookup COPIES the frames into the
  caller — about 1.6 MB — so testing sixty-nine ranked fights for drawability
  with `recording/1` would copy a hundred megabytes to answer sixty-nine
  booleans. That is the exact shape of the bug that OOM-killed this site, and it
  would have been reintroduced by the fix for the page that lists them.

  `:ets.member/2` answers from the key alone and copies nothing.
  """
  @spec holds?({atom(), binary()}) :: boolean()
  def holds?(key), do: :ets.member(@recordings, key)

  # Split the mass off a fact, keep the count, hand back what is safe to copy.
  defp stow(key, fact) do
    case Map.pop(fact, "frames") do
      {frames, light} when is_list(frames) -> filed(key, frames, light)
      {_absent, light} -> light
    end
  end

  defp filed(key, frames, light) do
    hold(weigh(frames), key, frames)
    Map.put(light, "frame_count", length(frames))
  end

  # Words, not bytes, and no allocation: `term_to_binary` would build the very
  # megabyte the measurement is trying to avoid.
  defp weigh(term), do: :erts_debug.size(term) * :erlang.system_info(:wordsize)

  defp hold(bytes, _key, _frames) when bytes > @max_recording, do: :ok

  defp hold(bytes, key, frames) do
    :ets.insert(@recordings, {key, System.system_time(:millisecond), bytes, frames})
    evict_recordings()
  end

  # Oldest first until the budget is met. The select projects key, time and size
  # and leaves the frames in the table — walking these to decide what to drop
  # must not copy the thing being measured.
  defp evict_recordings do
    held =
      @recordings
      |> :ets.select([{{:"$1", :"$2", :"$3", :_}, [], [{{:"$1", :"$2", :"$3"}}]}])
      |> Enum.sort_by(&elem(&1, 1))

    shrink(Enum.sum(Enum.map(held, &elem(&1, 2))), held)
  end

  defp shrink(total, _oldest_first) when total <= @budget, do: :ok
  defp shrink(_total, []), do: :ok

  defp shrink(total, [{key, _at, bytes} | rest]) do
    :ets.delete(@recordings, key)
    shrink(total - bytes, rest)
  end

  @doc "Raids the board is holding, newest first."
  def raids do
    @table
    |> :ets.select([{{{:raid, :_}, :"$1"}, [], [:"$1"]}])
    |> Enum.sort_by(& &1.last_seen, :desc)
  end

  # Oldest first, because a raid from an hour ago is not what anybody is looking
  # at, and a public realm is writable by anyone who can reach a station.
  defp evict_oldest_raids do
    case raids() do
      rows when length(rows) > @max_raids ->
        rows
        |> Enum.drop(@max_raids)
        |> Enum.each(&forget/1)

      _within ->
        :ok
    end
  end

  # The row and its recording go together. Left behind, a recording would sit in
  # the budget until it aged out, holding megabytes for a fight nothing can name.
  defp forget(%{id: id}) do
    :ets.delete(@table, {:raid, id})
    :ets.delete(@recordings, {:raid, id})
  end

  defp fresh(key), do: %{id: key, name: nil, facts: %{}, last_seen: nil}

  defp existing(key) do
    case :ets.lookup(@table, key) do
      [{^key, row}] -> row
      _otherwise -> nil
    end
  end

  @doc "Every island heard from, sorted by what it calls itself."
  def islands, do: rows() |> Map.values() |> Enum.sort_by(&label/1)

  @doc "What to call an island. The key is a digest and nobody wants to read one."
  def label(%{name: name}) when is_binary(name), do: name
  def label(%{id: id}), do: id

  @doc "One island's row, or nil."
  def island(key), do: existing(key)

  @doc "Islands refused because the cap was reached. Non-zero means the view lies."
  def refused do
    case :ets.lookup(@table, :refused) do
      [{:refused, n}] -> n
      [] -> 0
    end
  end

  @doc """
  Milliseconds since anything was last heard from this island.

  ⚠ WITHOUT THIS A DEAD ISLAND IS INVISIBLE. The board keeps the last fact
  forever, so an island whose trainer stopped, or whose transport did, goes on
  showing its final bout with a tick that never advances. At one island you would
  notice. At six you would not.
  """
  def quiet_for(%{last_seen: at}) when is_integer(at),
    do: System.system_time(:millisecond) - at

  def quiet_for(_never), do: nil

  # ⚠ ISLANDS ONLY. One table holds three shapes now — the `:refused` counter
  # under an atom, islands under a binary id, and raids under `{:raid, id}` — and
  # an island row has `:facts` while a raid row has `:parts`. Letting a raid
  # through here raised `key :facts not found` from inside the page, which is the
  # right kind of loud, but the filter belongs where the keys are known.
  #
  # ⚠ AND IT SELECTS RATHER THAN LISTING. `:ets.tab2list/1` copies every row into
  # the caller and then throws most of them away; the guard belongs in the match
  # spec, where it runs without copying. That difference is what OOM-killed the
  # site twelve times a day.
  defp rows do
    @table
    |> :ets.select([{{:"$1", :"$2"}, [{:is_binary, :"$1"}], [{{:"$1", :"$2"}}]}])
    |> Map.new()
  end
end
