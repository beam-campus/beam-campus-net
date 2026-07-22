defmodule BeamCampusWeb.Notebook do
  @moduledoc """
  The open lab notebook: plain-language (ELI5) posts derived from the signed faber
  research corpus. Compile-time — posts are markdown files in priv/notebook, parsed
  by NimblePublisher into `Post` structs. No database.

  The corpus (faber-ecosystem insights) is the source of truth; these posts are the
  reviewed public layer, each declaring its `sources` for provenance and depth.
  """

  alias BeamCampusWeb.Notebook.Post

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

  @doc "Fetch a post by its id (filename without .md); raises 404 if missing."
  def get_post_by_id!(id) do
    Enum.find(@posts, &(&1.id == id)) ||
      raise BeamCampusWeb.Notebook.NotFoundError, "notebook post not found: #{id}"
  end
end

defmodule BeamCampusWeb.Notebook.NotFoundError do
  defexception [:message, plug_status: 404]
end
