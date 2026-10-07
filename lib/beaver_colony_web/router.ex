defmodule BeaverColonyWeb.Router do
  use BeaverColonyWeb, :router

  import BeaverColonyWeb.BeaverAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BeaverColonyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_beaver
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BeaverColonyWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", BeaverColonyWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:beaver_colony, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BeaverColonyWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", BeaverColonyWeb do
    pipe_through [:browser, :require_authenticated_beaver]

    # Every signed-in live_session ends with BeaverColonyWeb.Nav, which loads the
    # sidebar and must see membership changes after BeaverAuth has acted on them.
    live_session :require_authenticated_beaver,
      on_mount: [{BeaverColonyWeb.BeaverAuth, :require_authenticated}, BeaverColonyWeb.Nav] do
      live "/beavers/settings", BeaverLive.Settings, :edit
      live "/beavers/settings/confirm-email/:token", BeaverLive.Settings, :confirm_email

      # Personal pages: the beaver's own data, no colony in the scope.
      live "/me/colonies", ColonyLive.Mine, :index
    end

    post "/beavers/update-password", BeaverSessionController, :update_password

    # Every colony page. The URL names the colony, :assign_colony puts it in the scope
    # with the beaver's role there, and each LiveView declares the ability it needs
    # with `on_mount {BeaverAuth, {:require, ability}}`. The router never names a role.
    live_session :colony,
      on_mount: [
        {BeaverColonyWeb.BeaverAuth, :require_authenticated},
        {BeaverColonyWeb.BeaverAuth, :assign_colony},
        BeaverColonyWeb.Nav
      ] do
      live "/colonies/:colony_id", ColonyLive.Dashboard, :show
      live "/colonies/:colony_id/members", ColonyLive.Members, :index
      live "/colonies/:colony_id/settings", ColonyLive.Settings, :edit
    end
  end

  scope "/", BeaverColonyWeb do
    pipe_through [:browser]

    live_session :current_beaver,
      on_mount: [{BeaverColonyWeb.BeaverAuth, :mount_current_scope}] do
      live "/beavers/register", BeaverLive.Registration, :new
      live "/beavers/log-in", BeaverLive.Login, :new
      live "/beavers/log-in/:token", BeaverLive.Confirmation, :new
    end

    post "/beavers/log-in", BeaverSessionController, :create
    delete "/beavers/log-out", BeaverSessionController, :delete
  end
end
