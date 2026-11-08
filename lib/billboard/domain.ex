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

  Each takes `opts` last, Ash's options for the action, and has its `!`
  form. Every write, and every read of a draft, needs an actor, so pass
  `actor:` (any actor is a signed-in user to billboard's policies) or, in
  seeds and scripts, `authorize?: false`.

  On the page record:

    * `fetch_page(pattern, opts)`: `{:ok, page}` for the route pattern,
      as `"/about"`, or `{:ok, nil}` before the page's first edit.
    * `fetch_library_page(opts)`: the shared-sections library's record,
      or `{:ok, nil}`.
    * `create_page(%{pattern: pattern}, opts)`: makes a page's record.
      `ensure_page/2`, below, makes it only if it has none.

  On versions (`Billboard.Version`):

    * `create_version(%{page_id: page_id}, opts)`: a new, empty draft of
      the page. A page has at most one draft.
    * `get_version(id, opts)`.
    * `list_live_versions(opts)`: every live version, with its page and
      its sections and their children.
    * `list_drafts(opts)`: every draft, with its page.
    * `get_draft(page_id, opts)`: the page's draft, with its sections and
      their children, or `{:ok, nil}`.
    * `edit_page(pattern, opts)`: the page's draft, made from its live
      version, or from its starter, if it has none; `nil` is the library.
    * `commit_page(pattern, opts)`: checks the draft against the rules
      (`Billboard.Rules`) and makes it the live version, replacing the
      old one.
    * `discard_page(pattern, opts)`: deletes the draft, if there is one,
      and returns `:ok`.

  On sections (`Billboard.Section`), each of which only works on a
  draft's section:

    * `create_section(attrs, opts)`: puts a section at the end of its
      version, or of its Two columns section. `attrs` are `version_id`,
      the draft's id; `content`, an `Ash.Union` of the component's key and
      its fields, as
      `%Ash.Union{type: :hero, value: Billboard.Component.build!(:hero, %{heading: "Welcome"})}`;
      and optionally `parent_id`, a Two columns section's id; `anchor`,
      its DOM id; `key`, made for it if not given; and `surface`, a name
      from `Billboard.Surfaces`, or nil for its kind's default.
    * `get_section(id, opts)`, and `get_section_by_key(version_id, key, opts)`.
    * `update_section(section, attrs, opts)`: changes its `content`,
      `anchor`, or `surface`.
    * `destroy_section(section, opts)`: removes it, and its columns'
      sections. A hero, and a fixed page's sections, can't go.
    * `arrange_sections(version_id, order, opts)`: puts the version's
      top-level sections in `order`, a list of every one's id.
    * `place_section(section, position, opts)`: sets its `position`, by
      which it's sorted among its siblings, leaving theirs as they are.
      `arrange_sections/3` reorders a whole version.

  And, from `Billboard.Pages`: `put_page(pattern, sections, opts)`,
  which makes a page hold exactly `sections` and publishes it, for seeds
  (the page kinds guide's "Pages from code" has a worked example);
  `migrate_sections(from, to, opts)`, which moves every stored section
  of the component `from`, live, drafted, and in the library, to the
  component `to`, an atom, or as a function of its stored fields says,
  or deletes them, in one transaction, with `dry_run: true` to see what
  it would do first (the page kinds guide's "Retiring a component" has
  a worked example); `draft_for(pattern, opts)`; `ensure_page(pattern, opts)`;
  `change_draft(pattern, fun, opts)`, which runs `fun` on the page's
  draft, as every editor change does; `swap_columns(columns, opts)`;
  `page_for(pattern)`, what visitors see; `shared_sections()`;
  `shared_section(key)`; `subscribe()`; `subscribe_page(pattern)`;
  `unsubscribe_page(pattern)`; `page_topic(pattern)`; and
  `drain_page_changes(pattern)`.
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
          define :edit_page, action: :edit, args: [:pattern]
          define :commit_page, action: :commit, args: [:pattern]
          define :discard_page, action: :discard, args: [:pattern]
        end

        resource unquote(resources[:section]) do
          define :create_section, action: :create
          define :get_section, action: :read, get_by: [:id]
          define :get_section_by_key, action: :read, get_by: [:version_id, :key]
          define :update_section, action: :update
          define :destroy_section, action: :destroy
          define :arrange_sections, action: :arrange, args: [:version_id, :order]
          define :place_section, action: :place, args: [:position]
        end
      end

      @doc "See `Billboard.Pages.draft_for/2`."
      defdelegate draft_for(pattern, opts \\ []), to: Billboard.Pages

      @doc "See `Billboard.Pages.ensure_page/2`."
      defdelegate ensure_page(pattern, opts \\ []), to: Billboard.Pages

      @doc "See `Billboard.Pages.change_draft/3`."
      defdelegate change_draft(pattern, fun, opts \\ []), to: Billboard.Pages

      @doc "See `Billboard.Pages.put_page/3`."
      defdelegate put_page(pattern, sections, opts \\ []), to: Billboard.Pages

      @doc "See `Billboard.Pages.migrate_sections/3`."
      defdelegate migrate_sections(from, to, opts \\ []), to: Billboard.Pages

      @doc "See `Billboard.Pages.swap_columns/2`."
      defdelegate swap_columns(columns, opts \\ []), to: Billboard.Pages

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
