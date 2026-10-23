defmodule Billboard.Site do
  @moduledoc """
  The site using billboard, described in one module:

      defmodule MySite.Billboard do
        alias MySite.Pages

        use Billboard.Site,
          otp_app: :my_site,
          repo: MySite.Repo,
          pubsub: MySite.PubSub,
          domain: Pages,
          resources: [
            page: Pages.Page,
            version: Pages.Version,
            section: Pages.Section,
            content: Pages.Content
          ],
          components: [MySite.Sections.Hero, MySite.Sections.Faq],
          surfaces: [%{name: "paper", label: "Paper"}, %{name: "band", label: "Aubergine"}],
          offered: [page: ["paper"], stand_out: ["band"], card: []],
          options: [points: [look: [:rows], columns: [3, 2], points: 1..3]],
          rules: [MySite.SiteRules],
          starter: MySite.Pages.Starter,
          reserved_ids: [ids: ~w(site-header site-footer), prefixes: ~w(team-)]

        pages do
          page "/", "Home", kind: :free, title: "A title for the browser"
          page "/services/:slug", "A service", kind: :service
          page "/price-list", "Price list", kind: :price_list, fixed: [:hero, :price_list]
          library "Shared sections"
        end
      end

  named in `config/config.exs`:

      config :billboard, site: MySite.Billboard

  ## Its answers

    * `otp_app` (required) is the site's application. A test overrides
      the answers under it (see Overriding in tests).
    * `repo` is its AshPostgres repo, which its pages, versions, and
      sections use.
    * `pubsub` is its `Phoenix.PubSub` server, on which editors and open
      pages hear about changes.
    * `domain` is its Ash domain for the pages, a module that does
      `use Billboard.Domain`.
    * `resources` names its page record, versions, sections, and content
      union: modules that do `use Billboard.Page`, `Billboard.Version`,
      `Billboard.Section`, and `Billboard.Content`.
    * `components` is its components, in palette order. The content
      union holds them in this order. Until stock components ship, this
      is the whole palette.
    * `surfaces`, `offered`, and `options`: see `Billboard.Surfaces` and
      `Billboard.SiteOptions`.
    * `rules` is its own page rules, each a `Billboard.Rule`, which run
      after the stock ones (`Billboard.Rules`).
    * `starter` names its `Billboard.Starter`, which says what a page
      shows before its first commit. Without one, pages start empty.
    * `reserved_ids` lists the DOM ids its own markup uses, which no
      section's anchor may take: whole `ids`, `prefixes`, `suffixes`,
      and `owned`, an id a component may take for itself, as
      `%{"reviews" => :reviews}`. Billboard adds the ids it draws itself
      (`Billboard.Section.Validations.AnchorAvailable`).

  The site module answers with its options, never with functions that
  call the site's other modules. Billboard reads the modules an answer
  names without making the site module depend on them, so the site
  module compiles against billboard alone. The content union and the
  resources read the answers as they compile, so they compile against
  the site module, and recompile whenever it does. A function written
  here that called, say, the site's starter would make every one of
  them recompile whenever the starter, or anything it calls, changes.
  That's why the starter is an answer.

  ## Its pages

  `pages do … end` lists the pages the builder knows, in the order the
  admin lists them (`Billboard.Directory`):

    * `page pattern, label, kind: kind` is a page at a route pattern,
      such as `"/services/:slug"`. `kind` is the site's own atom, which
      decides the components it may use (each component's `kinds`).
      `fixed:` lists, in order, the sections a fixed page must have,
      by component key, and `title:` is its browser title when that
      isn't the hero's heading.
    * `library label` is the shared-sections library, the page with no
      pattern, whose kind is `:library`. A site that doesn't write one
      gets `library "Shared sections"` after its pages.

  ## What it defines

  `use Billboard.Site` defines this behaviour's callbacks from the
  answers and the pages. A site may write any of them itself, and call
  billboard's with `super`.

  ## Overriding in tests

  A test can override the surfaces, offers, options, and rules under the
  site module's key in its application's env:

      config :my_site, MySite.Billboard,
        surfaces: [%{name: "bg", label: "Background"}, %{name: "night", label: "Night"}],
        offered: [page: ["bg"], stand_out: ["night", "bg"], card: ["bg"]],
        options: [points: [look: [:rows, :cards]]],
        rules: [MyTest.GroundRule]

  `:surfaces` replaces the whole list, and its first is the page's own.
  With it, `:offered` is the whole offer, since the site's names wouldn't
  be among the test's. Without it, `:offered` is merged over the site's
  offer one kind at a time, so a test can widen one kind and leave the
  rest. `:options` is merged over the site's one type at a time, then one
  field at a time. `:rules` replaces the site's rules whole.

  The components, the pages, and the resources can't be overridden: the
  content union and the resources are compiled from them.

  ## Written by hand

  A module may implement this behaviour itself, as billboard's own
  component tests do (`Billboard.Test.Site`). Only `components/0`,
  `surfaces/0`, `offered/0`, `options/0`, and `rules/0` are required, and
  they're enough for components, surfaces, and site options. Pages,
  resources, and the engine need the rest, which `use Billboard.Site`
  defines.
  """

  @typedoc "A surface's name, its `bb-surface-NAME` class, and the label the editor shows."
  @type surface :: %{name: String.t(), label: String.t()}

  @typedoc "A builder page's route pattern, or `nil` for the shared-sections library."
  @type pattern :: String.t() | nil

  @typedoc "The DOM ids a site's own markup uses. See `reserved_ids/0`."
  @type reserved_ids :: [
          ids: [String.t()],
          prefixes: [String.t()],
          suffixes: [String.t()],
          owned: %{String.t() => atom()}
        ]

  @doc "The site's components, stock and its own, in palette order."
  @callback components() :: [module()]

  @doc "The site's surfaces, in order. The first is the page's own."
  @callback surfaces() :: [surface()]

  @doc "For each kind of section or card, the surfaces it may take, in order. See `Billboard.Surfaces`."
  @callback offered() :: keyword([String.t()])

  @doc "The values the site offers in components' settings, by type and field. See `Billboard.SiteOptions`."
  @callback options() :: keyword(keyword())

  @doc "The site's own page rules, each a `Billboard.Rule`."
  @callback rules() :: [module()]

  @doc "The pages the builder knows, in the order the admin lists them, the library among them."
  @callback pages() :: [Billboard.Directory.Page.t()]

  @doc "The site's page record, versions, sections, and content union."
  @callback resources() :: keyword(module())

  @doc "The site's Ash domain for its pages, which does `use Billboard.Domain`."
  @callback domain() :: module() | nil

  @doc "The site's AshPostgres repo."
  @callback repo() :: module() | nil

  @doc "The site's `Phoenix.PubSub` server."
  @callback pubsub() :: atom() | nil

  @doc "What the page at `pattern` shows before its first commit. Never raises. See `Billboard.Starter`."
  @callback starter(pattern()) :: struct()

  @doc "Like `starter/1`, but raises when what the starter reads can't be read."
  @callback starter!(pattern()) :: struct()

  @doc "The DOM ids the site's own markup uses, which no section's anchor may take."
  @callback reserved_ids() :: reserved_ids()

  @optional_callbacks pages: 0,
                      resources: 0,
                      domain: 0,
                      repo: 0,
                      pubsub: 0,
                      starter: 1,
                      starter!: 1,
                      reserved_ids: 0

  @doc false
  defmacro __using__(opts) do
    {otp_app, answers} = Keyword.pop(opts, :otp_app)

    unless is_atom(otp_app) and not is_nil(otp_app) do
      raise ArgumentError,
            "`use Billboard.Site` needs `otp_app:`, the site's application, such as " <>
              "`otp_app: :my_site`. A test overrides the site's answers under it."
    end

    # Spark's own `use` drops every option when one isn't a literal, such
    # as a range or a sigil, so billboard reads the answers itself. It
    # expands their aliases as Spark does, without making this module
    # depend on the modules they name.
    answers = Spark.Dsl.Extension.expand_alias_no_require(answers, __CALLER__)

    quote do
      use Billboard.Site.Base, otp_app: unquote(otp_app)

      @behaviour Billboard.Site
      @billboard_answers Billboard.Site.Answers.validate!(unquote(answers), __MODULE__)
      @persist {:billboard_answers, @billboard_answers}

      @impl Billboard.Site
      def components, do: @billboard_answers[:components]

      @impl Billboard.Site
      def surfaces, do: Billboard.Site.Answers.surfaces(@billboard_answers, __billboard_env__())

      @impl Billboard.Site
      def offered, do: Billboard.Site.Answers.offered(@billboard_answers, __billboard_env__())

      @impl Billboard.Site
      def options, do: Billboard.Site.Answers.options(@billboard_answers, __billboard_env__())

      @impl Billboard.Site
      def rules, do: Billboard.Site.Answers.rules(@billboard_answers, __billboard_env__())

      @impl Billboard.Site
      def pages, do: Billboard.Site.Info.pages(__MODULE__)

      @impl Billboard.Site
      def resources, do: @billboard_answers[:resources]

      @impl Billboard.Site
      def domain, do: @billboard_answers[:domain]

      @impl Billboard.Site
      def repo, do: @billboard_answers[:repo]

      @impl Billboard.Site
      def pubsub, do: @billboard_answers[:pubsub]

      @impl Billboard.Site
      def starter(pattern), do: Billboard.Starter.version(@billboard_answers[:starter], pattern)

      @impl Billboard.Site
      def starter!(pattern), do: Billboard.Starter.version!(@billboard_answers[:starter], pattern)

      @impl Billboard.Site
      def reserved_ids, do: @billboard_answers[:reserved_ids]

      @doc false
      def __billboard_env__, do: Application.get_env(unquote(otp_app), __MODULE__, [])

      defoverridable components: 0,
                     surfaces: 0,
                     offered: 0,
                     options: 0,
                     rules: 0,
                     pages: 0,
                     resources: 0,
                     domain: 0,
                     repo: 0,
                     pubsub: 0,
                     starter: 1,
                     starter!: 1,
                     reserved_ids: 0
    end
  end

  @doc "The site's module. Raises when none is configured."
  @spec get!() :: module()
  def get! do
    Application.get_env(:billboard, :site) ||
      raise ArgumentError,
            "billboard doesn't know the site's module. Add " <>
              "`config :billboard, site: MySite.Billboard` to config/config.exs"
  end

  @doc "The site's components."
  @spec components() :: [module()]
  def components, do: get!().components()

  @doc """
  The component whose key is `type`. Raises for one the site doesn't list,
  and for a module in the site's list that isn't a component.
  """
  @spec component!(atom()) :: module()
  def component!(type) when is_atom(type) do
    Enum.find(components(), &(key!(&1) == type)) ||
      raise ArgumentError,
            "the site has no component #{inspect(type)}. Add its module to the site's components/0"
  end

  defp key!(module) do
    if Billboard.Component.Info.component?(module) do
      Billboard.Component.Info.component_key!(module)
    else
      raise ArgumentError,
            "the site's components/0 lists #{inspect(module)}, which isn't a billboard " <>
              "component. Add `use Billboard.Component` to it, or take it out of components/0"
    end
  end

  @doc "The site's pages (`Billboard.Directory`)."
  @spec pages() :: [Billboard.Directory.Page.t()]
  def pages,
    do: call!(:pages, [], "Give it `use Billboard.Site`, with a `pages do … end` section.")

  @doc """
  The site's resource named `name`: `:page`, `:version`, `:section`, or
  `:content`. Raises, naming the fix, when the site names none.
  """
  @spec resource!(:page | :version | :section | :content) :: module()
  def resource!(name) when name in [:page, :version, :section, :content] do
    resources = call!(:resources, [], "Give it `use Billboard.Site`, with `resources: [...]`.")
    module = name |> to_string() |> Macro.camelize()

    Keyword.get(resources, name) ||
      raise ArgumentError,
            "#{inspect(get!())} names no #{name} resource. Add `#{name}: MySite.Pages.#{module}` " <>
              "to the `resources:` of its `use Billboard.Site`, naming a module that does " <>
              "`use Billboard.#{module}`"
  end

  @doc "The site's domain for its pages. Raises, naming the fix, when it names none."
  @spec domain!() :: module()
  def domain!,
    do: answer!(:domain, "`domain: MySite.Pages`, a module that does `use Billboard.Domain`")

  @doc "The site's repo. Raises, naming the fix, when it names none."
  @spec repo!() :: module()
  def repo!, do: answer!(:repo, "`repo: MySite.Repo`, its AshPostgres repo")

  @doc "The site's PubSub server. Raises, naming the fix, when it names none."
  @spec pubsub!() :: atom()
  def pubsub!, do: answer!(:pubsub, "`pubsub: MySite.PubSub`, its Phoenix.PubSub server")

  @doc "What the page at `pattern` shows before its first commit (`Billboard.Starter`)."
  @spec starter(pattern()) :: struct()
  def starter(pattern), do: call!(:starter, [pattern], "Give it `use Billboard.Site`.")

  @doc "Like `starter/1`, but raises when what the starter reads can't be read."
  @spec starter!(pattern()) :: struct()
  def starter!(pattern), do: call!(:starter!, [pattern], "Give it `use Billboard.Site`.")

  @doc "The DOM ids the site's own markup uses, or none for a site that doesn't say."
  @spec reserved_ids() :: reserved_ids() | []
  def reserved_ids do
    site = get!()
    if exports?(site, :reserved_ids, 0), do: site.reserved_ids(), else: []
  end

  defp answer!(name, example) do
    call!(name, [], "Give it `use Billboard.Site`, with #{example}.") ||
      raise ArgumentError,
            "#{inspect(get!())} names no #{name}. Add #{example} to its `use Billboard.Site`"
  end

  defp call!(name, args, fix) do
    site = get!()

    if exports?(site, name, length(args)),
      do: apply(site, name, args),
      else:
        raise(ArgumentError, "#{inspect(site)} doesn't define #{name}/#{length(args)}. #{fix}")
  end

  defp exports?(module, name, arity),
    do: Code.ensure_loaded?(module) and function_exported?(module, name, arity)
end
