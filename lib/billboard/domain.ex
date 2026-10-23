defmodule Billboard.Domain do
  @moduledoc """
  The site's domain for its pages: billboard's page record, versions, and
  sections, with their code interfaces, and the engine's functions.

      defmodule MySite.Pages do
        use Billboard.Domain, site: MySite.Billboard, extensions: [AshPhoenix]
      end

  It takes `use Ash.Domain`'s options too, such as `extensions:`, and
  the site's `otp_app` unless given. List it in the site's `ash_domains`.

  ## Its functions

  On the page record, `fetch_page/2`, `fetch_library_page/1`, and
  `create_page/2`. On versions, `create_version/2`, `get_version/2`,
  `list_live_versions/1`, `list_drafts/1`, and `get_draft/2`. On
  sections, `create_section/2`, `get_section/2`, `get_section_by_key/3`,
  `update_section/3`, `destroy_section/2`, and `place_section/3`. Each
  has its `!` form.

  And, from `Billboard.Pages`, `ensure_page(pattern, opts)`,
  `page_for(pattern)`, `shared_sections()`, `shared_section(key)`,
  `subscribe()`, `subscribe_page(pattern)`, `unsubscribe_page(pattern)`,
  `page_topic(pattern)`, and `drain_page_changes(pattern)`.
  """

  @doc false
  defmacro __using__(opts) do
    site = Billboard.Resource.site!(opts, __CALLER__, :domain)
    resources = site.resources
    ash_opts = opts |> Keyword.delete(:site) |> Keyword.put_new(:otp_app, site.otp_app)

    quote do
      require unquote(site.module)
      use Ash.Domain, unquote(ash_opts)

      resources do
        resource unquote(resources[:page]) do
          define :fetch_library_page, action: :library, not_found_error?: false
          define :fetch_page, action: :by_pattern, args: [:pattern], not_found_error?: false
          define :create_page, action: :create
        end

        resource unquote(resources[:version]) do
          define :create_version, action: :create
          define :get_version, action: :read, get_by: [:id]
          define :list_live_versions, action: :live
          define :list_drafts, action: :drafts
          define :get_draft, action: :draft, args: [:page_id], not_found_error?: false
        end

        resource unquote(resources[:section]) do
          define :create_section, action: :create
          define :get_section, action: :read, get_by: [:id]
          define :get_section_by_key, action: :read, get_by: [:version_id, :key]
          define :update_section, action: :update
          define :destroy_section, action: :destroy
          define :place_section, action: :place, args: [:position]
        end
      end

      @doc "See `Billboard.Pages.ensure_page/2`."
      defdelegate ensure_page(pattern, opts \\ []), to: Billboard.Pages

      @doc "See `Billboard.Pages.page_for/1`."
      defdelegate page_for(pattern), to: Billboard.Pages

      @doc "See `Billboard.Pages.shared_sections/0`."
      defdelegate shared_sections(), to: Billboard.Pages

      @doc "See `Billboard.Pages.shared_section/1`."
      defdelegate shared_section(key), to: Billboard.Pages

      @doc "See `Billboard.Pages.subscribe/0`."
      defdelegate subscribe(), to: Billboard.Pages

      @doc "See `Billboard.Pages.subscribe_page/1`."
      defdelegate subscribe_page(pattern), to: Billboard.Pages

      @doc "See `Billboard.Pages.unsubscribe_page/1`."
      defdelegate unsubscribe_page(pattern), to: Billboard.Pages

      @doc "See `Billboard.Pages.page_topic/1`."
      defdelegate page_topic(pattern), to: Billboard.Pages

      @doc "See `Billboard.Pages.drain_page_changes/1`."
      defdelegate drain_page_changes(pattern), to: Billboard.Pages
    end
  end
end
