defmodule StrangepathsWeb.Router do
  use StrangepathsWeb, :router

  import StrangepathsWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {StrangepathsWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_user)
    plug(:fetch_user_role)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", StrangepathsWeb do
    pipe_through(:browser)

    get("/", PageController, :index)

    # Secure music file serving
    get("/music/:guid", MusicFileController, :serve)

    live("/ost", OstLive)
    live("/ost/:id", SongLive)

    live("/ascension", Ascension)
    live("/scenes", Scenes)
    live("/scenes/archives", Scenes.Archives)

    live("/content", ContentIndexLive)
    live("/content/admin", ContentAdminLive)
    live("/content/:slug", ContentLive)

    live("/avatars/admin", AvatarAdminLive)

    live("/lab/cardgen", CardGenLive)

    live("/codex", DeckLive.Index, :index)
    live("/codex/new", DeckLive.Index, :new)

    live("/codex/:id", DeckLive.Show, :show)
    live("/codex/:id/show/edit", DeckLive.Show, :edit)

    live("/cosmos", CardLive.Index, :index)
    live("/cosmos/new", CardLive.Index, :new)

    live("/cosmos/:id", CardLive.Show, :show)
    live("/cosmos/:id/show/edit", CardLive.Show, :edit)

    live("/ceremony", CeremonyLive.Index, :index)
    live("/ceremony/new", CeremonyLive.Index, :new)
    live("/ceremony/:id", CeremonyLive.Show, :show)
  end

  # Other scopes may use custom stacks.
  # scope "/api", StrangepathsWeb do
  #   pipe_through :api
  # end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through(:browser)

      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end

  ## Authentication routes

  scope "/", StrangepathsWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    get("/users/register", UserRegistrationController, :new)
    post("/users/register", UserRegistrationController, :create)
    get("/users/log_in", UserSessionController, :new)
    post("/users/log_in", UserSessionController, :create)
    get("/users/reset_password", UserResetPasswordController, :new)
    post("/users/reset_password", UserResetPasswordController, :create)
    get("/users/reset_password/:token", UserResetPasswordController, :edit)
    put("/users/reset_password/:token", UserResetPasswordController, :update)
  end

  scope "/", StrangepathsWeb do
    import Phoenix.LiveDashboard.Router
    pipe_through([:browser, :require_authenticated_user])

    live_dashboard("/dashboard", metrics: StrangepathsWeb.Telemetry)
    get("/users/settings", UserSettingsController, :edit)
    put("/users/settings", UserSettingsController, :update)
    get("/users/settings/confirm_email/:token", UserSettingsController, :confirm_email)
  end

  scope "/", StrangepathsWeb do
    pipe_through([:browser])

    delete("/users/log_out", UserSessionController, :delete)
    get("/users/confirm", UserConfirmationController, :new)
    post("/users/confirm", UserConfirmationController, :create)
    get("/users/confirm/:token", UserConfirmationController, :edit)
    post("/users/confirm/:token", UserConfirmationController, :update)
  end
end
