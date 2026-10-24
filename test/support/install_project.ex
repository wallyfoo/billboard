defmodule Billboard.Test.InstallProject do
  @moduledoc """
  A site as `mix phx.new my_site`, `mix phx.gen.auth Accounts User
  users --live`, and Ash's installers leave it, in memory, for the
  generators' tests: Igniter's Phoenix test project, with phx.gen.auth's
  router (its two live_sessions: the signed-in one, and `:current_user`,
  which every page whose root layout reads `@current_scope` joins) and
  an AshPostgres repo. The router is phx.new's with phx.gen.auth's
  plug and routes, as its templates write them.

  Igniter formats a test project without its dependencies' formatter
  rules, so DSL calls come out with parentheses: assert on what's
  written, not on how it's laid out.
  """
  import Igniter.Test

  @router """
  defmodule MySiteWeb.Router do
    use MySiteWeb, :router

    import MySiteWeb.UserAuth

    pipeline :browser do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :fetch_live_flash
      plug :put_root_layout, html: {MySiteWeb.Layouts, :root}
      plug :protect_from_forgery
      plug :put_secure_browser_headers
      plug :fetch_current_scope_for_user
    end

    pipeline :api do
      plug :accepts, ["json"]
    end

    scope "/", MySiteWeb do
      pipe_through :browser

      get "/", PageController, :home
    end

    # Enable LiveDashboard and Swoosh mailbox preview in development
    if Application.compile_env(:my_site, :dev_routes) do
      import Phoenix.LiveDashboard.Router

      scope "/dev" do
        pipe_through :browser

        live_dashboard "/dashboard", metrics: MySiteWeb.Telemetry
        forward "/mailbox", Plug.Swoosh.MailboxPreview
      end
    end

    ## Authentication routes

    scope "/", MySiteWeb do
      pipe_through [:browser, :require_authenticated_user]

      live_session :require_authenticated_user,
        on_mount: [{MySiteWeb.UserAuth, :require_authenticated}] do
        live "/users/settings", UserLive.Settings, :edit
        live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      end

      post "/users/update-password", UserSessionController, :update_password
    end

    scope "/", MySiteWeb do
      pipe_through [:browser]

      live_session :current_user,
        on_mount: [{MySiteWeb.UserAuth, :mount_current_scope}] do
        live "/users/register", UserLive.Registration, :new
        live "/users/log-in", UserLive.Login, :new
        live "/users/log-in/:token", UserLive.Confirmation, :new
      end

      post "/users/log-in", UserSessionController, :create
      delete "/users/log-out", UserSessionController, :delete
    end
  end
  """

  @repo """
  defmodule MySite.Repo do
    use AshPostgres.Repo, otp_app: :my_site

    def installed_extensions, do: ["ash-functions"]
  end
  """

  @doc "The project, with the router and repo as above, and `files` over them."
  def project(files \\ %{}) do
    files =
      Map.merge(
        %{"lib/my_site_web/router.ex" => @router, "lib/my_site/repo.ex" => @repo},
        files
      )

    files
    |> Enum.reduce(phx_test_project(app_name: :my_site), fn {path, content}, igniter ->
      Igniter.create_or_update_file(
        igniter,
        path,
        content,
        &Rewrite.Source.update(&1, :content, content)
      )
    end)
    |> apply_igniter!()
  end

  @doc "Igniter's phx.new project as it is, its repo an Ecto one."
  def without_ash, do: phx_test_project(app_name: :my_site)

  @doc "The content of `path` after `igniter`'s changes."
  def content(igniter, path) do
    igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
  end
end
