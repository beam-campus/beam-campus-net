defmodule BeamCampusWeb.Router do
  use BeamCampusWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BeamCampusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BeamCampusWeb do
    pipe_through :browser

    live "/", HomeLive, :index
    # /research is the hub over the research lines; each line owns its own page.
    live "/research", ResearchLive, :index
    live "/research/faber", FaberLive, :index
    live "/research/spartan", SpartanLive, :index
    live "/research/notes", NotebookLive, :index
    live "/research/notes/:id", NotebookLive, :show
    live "/research/workbench", WorkbenchLive, :index
    live "/research/workbench/adaptation", AdaptationLive, :index
    live "/research/workbench/deception-maze", DeceptionMazeLive, :index
    live "/research/workbench/red-queen", RedQueenLive, :index
    live "/research/workbench/neural-coevolution", NeuralCoevolutionLive, :index
    live "/research/workbench/robo-rumble", RoboRumbleLive, :index
    live "/research/workbench/biotope", BiotopeLive, :index
    live "/research/workbench/biotope/history", BiotopeHistoryLive, :index
    # legacy alias — the adaptation demo used to live here
    live "/research/adaptation", AdaptationLive, :index
  end

  scope "/", BeamCampusWeb do
    pipe_through :api

    get "/health", HealthController, :show
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:beam_campus_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BeamCampusWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
