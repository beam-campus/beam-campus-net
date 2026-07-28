defmodule BeamCampusWeb.Notebook.Post do
  @moduledoc """
  One Notebook post. Frontmatter (an Elixir map at the top of the .md file):

      %{
        title: "...",
        date: ~D[2026-07-22],
        description: "one-line teaser",
        tags: ["p3", "memory"],
        sources: [35, 39, 41],          # signed insight numbers this draws on
        corpus_ref: "insight 046 / faber-ecosystem@0e8b2d0"
      }

  `sources` + `corpus_ref` are the provenance: they render as "the rigorous version"
  links and let a drift check know which corpus state a post was written against.
  """

  @enforce_keys [:id, :title, :body, :description, :date]
  defstruct [
    :id,
    :title,
    :body,
    :description,
    :date,
    :corpus_ref,
    :reading,
    tags: [],
    sources: []
  ]

  def build(filename, attrs, body) do
    id = filename |> Path.basename() |> Path.rootname()

    words =
      body |> String.replace(~r/<[^>]+>/, " ") |> String.split(~r/\s+/, trim: true) |> length()

    reading = max(1, div(words, 200))
    struct!(__MODULE__, [id: id, body: body, reading: reading] ++ Map.to_list(attrs))
  end
end
