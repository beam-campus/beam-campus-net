defmodule BeamCampusWeb.NotebookLive do
  @moduledoc """
  The open lab notebook: an index of posts and the individual post view. Posts are
  compiled markdown (BeamCampusWeb.Notebook); each links back to the signed corpus.
  """
  use BeamCampusWeb, :live_view

  alias BeamCampusWeb.Notebook
  alias BeamCampusWeb.Notebook.Post

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, corpora: Notebook.corpora_with_posts())}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    post = Notebook.get_post_by_id!(id)

    {:noreply,
     assign(socket,
       page_title: post.title,
       post: post,
       corpus_url: Notebook.corpus_url(post.corpus)
     )}
  end

  def handle_params(params, _uri, socket) do
    line = parse_line(params["line"])

    {:noreply,
     assign(socket, page_title: "Notebook", post: nil, line: line, posts: posts_for(line))}
  end

  # An unknown or absent ?line= shows everything rather than failing; the slug never
  # becomes an atom, so a crafted query string cannot grow the atom table.
  defp parse_line(nil), do: nil
  defp parse_line(slug), do: Enum.find(Post.corpora(), &(Atom.to_string(&1) == slug))

  defp posts_for(nil), do: Notebook.all_posts()
  defp posts_for(corpus), do: Notebook.posts_in(corpus)

  # --- index --------------------------------------------------------------------

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-3xl px-6 py-16">
        <p class="font-mono text-xs uppercase tracking-[0.22em] text-primary mb-4">
          BEAM Campus · open lab notebook
        </p>
        <h1 class="text-3xl sm:text-4xl font-semibold tracking-tight text-balance mb-4">
          The notebook
        </h1>
        <p class="text-base-content/70 max-w-2xl mb-10">
          Plain-language dispatches from the research, written for anyone. We do our science in the open,
          including the parts where we were wrong. Every post links back to the signed, dated corpus so you can
          check our work.
        </p>

        <div class="flex flex-wrap items-center gap-2 mb-8">
          <span class="font-mono text-[11px] uppercase tracking-widest text-base-content/50 mr-1">
            Line
          </span>
          <.link
            patch={~p"/research/notes"}
            class={["btn btn-xs", is_nil(@line) && "btn-primary", @line && "btn-ghost"]}
          >
            All
          </.link>
          <.link
            :for={c <- @corpora}
            patch={~p"/research/notes?line=#{c}"}
            class={["btn btn-xs", @line == c && "btn-primary", @line != c && "btn-ghost"]}
          >
            {Notebook.corpus_label(c)}
          </.link>
        </div>

        <ul class="flex flex-col gap-4">
          <li :for={post <- @posts}>
            <.link navigate={~p"/research/notes/#{post.id}"} class="block group">
              <article class="card bg-base-100 border border-base-300 transition-colors group-hover:border-primary/60">
                <div class="card-body gap-2">
                  <div class="flex flex-wrap items-center gap-2 font-mono text-[11px] text-base-content/50">
                    <time>{Calendar.strftime(post.date, "%d %b %Y")}</time>
                    <span>·</span>
                    <span>{post.reading} min</span>
                    <span class="badge badge-sm badge-outline">
                      {Notebook.corpus_label(post.corpus)}
                    </span>
                    <span :for={tag <- post.tags} class="badge badge-sm badge-ghost">{tag}</span>
                  </div>
                  <h2 class="text-xl font-semibold tracking-tight group-hover:text-primary">
                    {post.title}
                  </h2>
                  <p class="text-base-content/70 text-sm">{post.description}</p>
                </div>
              </article>
            </.link>
          </li>
        </ul>

        <p :if={@posts == []} class="text-base-content/50 font-mono text-sm">No posts yet.</p>
      </div>
    </Layouts.app>
    """
  end

  # --- single post --------------------------------------------------------------

  def render(%{live_action: :show} = assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <article class="mx-auto max-w-2xl px-6 py-16">
        <.link navigate={~p"/research/notes"} class="link link-hover font-mono text-xs text-primary">
          &larr; the notebook
        </.link>
        <div class="mt-6 flex flex-wrap items-center gap-2 font-mono text-[11px] text-base-content/50">
          <time>{Calendar.strftime(@post.date, "%d %b %Y")}</time>
          <span>·</span>
          <span>{@post.reading} min read</span>
          <span class="badge badge-sm badge-outline">{Notebook.corpus_label(@post.corpus)}</span>
          <span :for={tag <- @post.tags} class="badge badge-sm badge-ghost">{tag}</span>
        </div>
        <h1 class="mt-3 text-3xl sm:text-4xl font-semibold tracking-tight text-balance">
          {@post.title}
        </h1>
        <p class="mt-3 text-lg text-base-content/70">{@post.description}</p>

        <div class="nb-body mt-8">{Phoenix.HTML.raw(@post.body)}</div>

        <footer class="mt-12 pt-6 border-t border-base-300">
          <p class="font-mono text-xs uppercase tracking-[0.1em] text-base-content/50 mb-1">
            Provenance
          </p>
          <p class="text-sm text-base-content/70">
            Drawn from signed
            <span class="font-mono">{Notebook.corpus_label(@post.corpus)}</span>
            insights <span class="font-mono">{@post.sources |> Enum.map(&"##{&1}") |> Enum.join(", ")}</span>.
            Written against <span class="font-mono">{@post.corpus_ref}</span>.
            <a href={@corpus_url} target="_blank" rel="noreferrer" class="link link-hover text-primary">
              Read the rigorous version &rarr;
            </a>
          </p>
        </footer>
      </article>
    </Layouts.app>
    """
  end
end
