defmodule BeamCampusWeb.Notebook do
  @moduledoc """
  The open lab notebook: plain-language (ELI5) posts derived from the signed faber
  research corpus. Compile-time — posts are markdown files in priv/notebook, parsed
  by NimblePublisher into `Post` structs. No database.

  The signed corpora are the source of truth; these posts are the reviewed public
  layer, each declaring its `corpus` and `sources` for provenance and depth.

  The notebook spans more than one research line. Each line keeps its own corpus and
  numbers its insights from 001, so a post's `corpus` decides which repository its
  `sources` resolve against. Never resolve an insight number without it.
  """

  alias BeamCampusWeb.Notebook.Post

  @corpus_urls %{
    faber: "https://github.com/rgfaber/faber-ecosystem/blob/master/insights/INDEX.md",
    spartan: "https://github.com/hecate-services/hecate-spartan/blob/main/insights/README.md"
  }

  @corpus_labels %{faber: "Faber", spartan: "Spartan"}

  use NimblePublisher,
    build: Post,
    from: Path.join([__DIR__, "../../priv/notebook/**/*.md"]),
    as: :posts,
    highlighters: []

  @posts Enum.sort_by(@posts, & &1.date, {:desc, Date})
  @tags @posts |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()

  @doc "All posts, newest first."
  def all_posts, do: @posts

  @doc "All tags used across posts."
  def all_tags, do: @tags

  @doc "Posts belonging to one research line, newest first."
  def posts_in(corpus), do: Enum.filter(@posts, &(&1.corpus == corpus))

  @doc "The research lines that actually have posts, in a stable order."
  def corpora_with_posts do
    Enum.filter(Post.corpora(), fn c -> Enum.any?(@posts, &(&1.corpus == c)) end)
  end

  @doc "Canonical index URL for a research line's signed corpus."
  def corpus_url(corpus), do: Map.fetch!(@corpus_urls, corpus)

  @doc "Human label for a research line."
  def corpus_label(corpus), do: Map.fetch!(@corpus_labels, corpus)

  @doc "Fetch a post by its id (filename without .md); raises 404 if missing."
  def get_post_by_id!(id) do
    Enum.find(@posts, &(&1.id == id)) ||
      raise BeamCampusWeb.Notebook.NotFoundError, "notebook post not found: #{id}"
  end
end

defmodule BeamCampusWeb.Notebook.NotFoundError do
  defexception [:message, plug_status: 404]
end
