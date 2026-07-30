defmodule BeamCampusWeb.Notebook.Post do
  @moduledoc """
  One Notebook post. Frontmatter (an Elixir map at the top of the .md file):

      %{
        title: "...",
        date: ~D[2026-07-22],
        description: "one-line teaser",
        corpus: :faber,                 # which research line this post belongs to
        tags: ["p3", "memory"],
        sources: [35, 39, 41],          # signed insight numbers, scoped to `corpus`
        corpus_ref: "insight 046 / faber-ecosystem@0e8b2d0"
      }

  `corpus` + `sources` + `corpus_ref` are the provenance: they render as "the rigorous
  version" links and let a drift check know which corpus state a post was written
  against.

  `corpus` is mandatory and carries real weight. Each research line numbers its own
  insights from 001, so a bare `sources: [12]` is ambiguous across lines and would
  resolve against the wrong repository. Missing or unknown values fail the build
  rather than defaulting, because a silent default is exactly the wrong answer here.
  """

  @corpora [:faber, :spartan]

  @enforce_keys [:id, :title, :body, :description, :date, :corpus]
  defstruct [
    :id,
    :title,
    :body,
    :description,
    :date,
    :corpus,
    :corpus_ref,
    :reading,
    tags: [],
    sources: []
  ]

  @doc "The research lines a post may belong to."
  def corpora, do: @corpora

  def build(filename, attrs, body) do
    id = filename |> Path.basename() |> Path.rootname()
    validate_corpus!(id, attrs)

    words =
      body |> String.replace(~r/<[^>]+>/, " ") |> String.split(~r/\s+/, trim: true) |> length()

    reading = max(1, div(words, 200))
    struct!(__MODULE__, [id: id, body: body, reading: reading] ++ Map.to_list(attrs))
  end

  defp validate_corpus!(_id, %{corpus: corpus}) when corpus in @corpora, do: :ok

  defp validate_corpus!(id, %{corpus: corpus}) do
    raise ArgumentError,
          "notebook post #{id}: unknown corpus #{inspect(corpus)}, expected one of #{inspect(@corpora)}"
  end

  defp validate_corpus!(id, _attrs) do
    raise ArgumentError,
          "notebook post #{id}: missing :corpus. Each research line numbers its insights " <>
            "from 001, so a post must name the line its sources belong to. " <>
            "Expected one of #{inspect(@corpora)}."
  end
end
