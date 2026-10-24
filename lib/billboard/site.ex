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
          surfaces: [%{name: "paper", label: "Paper"}, %{name: "band", label: "Band"}],
          offered: [page: ["paper"], stand_out: ["band"], card: []],
          options: [points: [look: [:rows], columns: [3, 2], points: 1..3]],
          rules: [MySite.SiteRules],
          starter: MySite.Pages.Starter,
          reserved_ids: [ids: ~w(site-header site-footer), prefixes: ~w(team-)],
          actions: MySiteWeb.Actions,
          context: MySite.Pages.Context,
          data: MySite.Pages.Data,
          layout: MySiteWeb.Layouts,
          kinds: [faq: [:free, :service]],
          palette: [hints: [faq: "Questions, each with its answer."], categories: [content: "Words"]],
          example_path: "/about"

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
    * `components` is its components, in palette order: the whole
      palette, billboard's stock components (`Billboard.Components.Hero`
      and the rest) among the site's own wherever it lists them. The
      content union holds them in this order.
    * `surfaces`, `offered`, and `options`: see `Billboard.Surfaces` and
      `Billboard.SiteOptions`.
    * `rules` is its own page rules, each a `Billboard.Rule`, which run
      after the stock ones (`Billboard.Rules`).
    * `starter` names its `Billboard.Starter`, which says what a page
      shows before its first commit. Without one, each page starts as an
      empty version of its `version` resource.
    * `reserved_ids` lists the DOM ids its own markup uses, which no
      section's anchor may take: whole `ids`, `prefixes`, `suffixes`,
      and `owned`, an id a component may take for itself, as
      `%{"reviews" => :reviews}`. Billboard adds the ids it draws itself
      (`Billboard.Section.Validations.AnchorAvailable`).
    * `actions` names its `Billboard.Actions`: the site's own kinds of
      action, such as booking or ringing, and the component that draws
      them. Without one, an action is a link to a page on the site.
    * `context` names its `Billboard.Context`: the bindings a hero may
      take, and the choices the editor's pickers offer. Without one,
      there are no bindings and no choices.
    * `data` names its `Billboard.Data`: what the sections that draw rows
      from outside the builder, such as reviews and news, read for each
      page (`Billboard.Resolver`). Without one, they draw none.
    * `layout` names its `Billboard.Layout`: the site's chrome, its
      header and footer, which the page (`Billboard.Sections.page/1`) and
      the editor draw round every page, and the site's own data for it.
    * `kinds` narrows, by component key, the page kinds a component may
      go on, over the component's own `kinds`. A component it leaves out
      keeps its own. See `Billboard.Catalogue`.
    * `palette` sets the palette's words: `hints:`, by component key,
      over each component's own hint, and `categories:`, each category's
      label. See `Billboard.Catalogue.category_label/1`.
    * `example_path` is a page on the site, which the editor's hints and
      one of its messages give as an example. It's `"/about"` unless the
      site says.

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

  A test can override the surfaces, offers, options, rules, kinds, and
  palette under the site module's key in its application's env:

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
  field at a time. `:rules`, `:kinds`, and `:palette` each replace the
  site's whole.

  The components, the pages, and the resources can't be overridden: the
  content union and the resources are compiled from them.

  ## Written by hand

  A module may implement this behaviour itself, as billboard's own
  component tests do (`Billboard.Test.Site`). Only `components/0`,
  `surfaces/0`, `offered/0`, `options/0`, and `rules/0` are required, and
  they're enough for components, surfaces, and site options. Pages,
  resources, and the engine need the rest, which `use Billboard.Site`
  defines. A hand-written site that leaves out `actions/0`, `context/0`,
  `data/0`, `layout/0`, `kinds/0`, `palette/0`, or `example_path/0`
  reads as one that gave none (`actions/0` and the rest below).
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

  @doc "The site's components, in palette order."
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

  @doc """
  What the page at `pattern` shows before its first commit. It doesn't
  raise when what the starter reads can't be read. See `Billboard.Starter`.
  """
  @callback starter(pattern()) :: struct()

  @doc "Like `starter/1`, but raises when what the starter reads can't be read."
  @callback starter!(pattern()) :: struct()

  @doc "The DOM ids the site's own markup uses, which no section's anchor may take."
  @callback reserved_ids() :: reserved_ids()

  @doc "The site's action kinds and the component that draws them (`Billboard.Actions`), or nil for links alone."
  @callback actions() :: module() | nil

  @doc "What the site's pages are about (`Billboard.Context`), or nil."
  @callback context() :: module() | nil

  @doc "What the site reads for the sections that draw rows from outside the builder (`Billboard.Data`), or nil."
  @callback data() :: module() | nil

  @doc "The site's chrome round every page (`Billboard.Layout`), or nil."
  @callback layout() :: module() | nil

  @doc "The page kinds each component the site narrows may go on, by key."
  @callback kinds() :: keyword([atom()])

  @doc "The palette's words the site sets: `hints:` by component key, and `categories:` by category."
  @callback palette() :: keyword(keyword(String.t()))

  @doc ~S|A page on the site, as the editor's hints give one, such as "/about".|
  @callback example_path() :: String.t()

  @optional_callbacks pages: 0,
                      resources: 0,
                      domain: 0,
                      repo: 0,
                      pubsub: 0,
                      starter: 1,
                      starter!: 1,
                      reserved_ids: 0,
                      actions: 0,
                      context: 0,
                      data: 0,
                      layout: 0,
                      kinds: 0,
                      palette: 0,
                      example_path: 0

  @doc false
  defmacro __using__(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "`use Billboard.Site` takes its answers as a keyword list written in place, " <>
              "such as `use Billboard.Site, otp_app: :my_site, components: [...]`, " <>
              "not #{Macro.to_string(opts)}"
    end

    {otp_app, answers} = Keyword.pop(opts, :otp_app)

    cond do
      is_nil(otp_app) ->
        raise ArgumentError,
              "`use Billboard.Site` needs `otp_app:`, the site's application, such as " <>
                "`otp_app: :my_site`. A test overrides the site's answers under it."

      not is_atom(otp_app) ->
        raise ArgumentError,
              "`use Billboard.Site` needs `otp_app:` as an atom, such as `otp_app: :my_site`, " <>
                "not #{Macro.to_string(otp_app)}"

      true ->
        :ok
    end

    # Spark's own `use` drops every option when one isn't a literal, such
    # as a range or a sigil, so billboard reads the answers itself. It
    # expands their aliases as Spark does, without making this module
    # depend on the modules they name.
    answers = Spark.Dsl.Extension.expand_alias_no_require(answers, __CALLER__)

    quote do
      # Before Spark's `use`, which sets attributes of its own, such as
      # `@opts`, that an answer naming the site's attribute would read.
      @billboard_answers Billboard.Site.Answers.validate!(unquote(answers), __MODULE__)

      use Billboard.Site.Base, otp_app: unquote(otp_app)

      @behaviour Billboard.Site
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
      def starter(pattern),
        do: Billboard.Starter.version(@billboard_answers[:starter], pattern, __MODULE__)

      @impl Billboard.Site
      def starter!(pattern),
        do: Billboard.Starter.version!(@billboard_answers[:starter], pattern, __MODULE__)

      @impl Billboard.Site
      def reserved_ids, do: @billboard_answers[:reserved_ids]

      @impl Billboard.Site
      def actions, do: @billboard_answers[:actions]

      @impl Billboard.Site
      def context, do: @billboard_answers[:context]

      @impl Billboard.Site
      def data, do: @billboard_answers[:data]

      @impl Billboard.Site
      def layout, do: @billboard_answers[:layout]

      @impl Billboard.Site
      def kinds, do: Billboard.Site.Answers.kinds(@billboard_answers, __billboard_env__())

      @impl Billboard.Site
      def palette, do: Billboard.Site.Answers.palette(@billboard_answers, __billboard_env__())

      @impl Billboard.Site
      def example_path, do: @billboard_answers[:example_path]

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
                     reserved_ids: 0,
                     actions: 0,
                     context: 0,
                     data: 0,
                     layout: 0,
                     kinds: 0,
                     palette: 0,
                     example_path: 0
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
    do: answer!(:domain, "`domain: MySite.Pages`", "a module that does `use Billboard.Domain`")

  @doc "The site's repo. Raises, naming the fix, when it names none."
  @spec repo!() :: module()
  def repo!, do: answer!(:repo, "`repo: MySite.Repo`", "its AshPostgres repo")

  @doc "The site's PubSub server. Raises, naming the fix, when it names none."
  @spec pubsub!() :: atom()
  def pubsub!, do: answer!(:pubsub, "`pubsub: MySite.PubSub`", "its Phoenix.PubSub server")

  @doc "What the page at `pattern` shows before its first commit (`Billboard.Starter`)."
  @spec starter(pattern()) :: struct()
  def starter(pattern), do: call!(:starter, [pattern], "Give it `use Billboard.Site`.")

  @doc "Like `starter/1`, but raises when what the starter reads can't be read."
  @spec starter!(pattern()) :: struct()
  def starter!(pattern), do: call!(:starter!, [pattern], "Give it `use Billboard.Site`.")

  @doc "The DOM ids the site's own markup uses, each list empty for a site that doesn't say."
  @spec reserved_ids() :: reserved_ids()
  def reserved_ids, do: optional(:reserved_ids, Billboard.Site.Answers.no_reserved_ids())

  @doc "The site's actions module (`Billboard.Actions`), or nil for links alone."
  @spec actions() :: module() | nil
  def actions, do: optional(:actions, nil)

  @doc "The site's context module (`Billboard.Context`), or nil."
  @spec context() :: module() | nil
  def context, do: optional(:context, nil)

  @doc "The site's data module (`Billboard.Data`), or nil."
  @spec data() :: module() | nil
  def data, do: optional(:data, nil)

  @doc "The site's layout module (`Billboard.Layout`), or nil."
  @spec layout() :: module() | nil
  def layout, do: optional(:layout, nil)

  @doc "The page kinds the site keeps each component it narrows to, by key."
  @spec kinds() :: keyword([atom()])
  def kinds, do: optional(:kinds, [])

  @doc "The palette's words the site sets (`hints:` and `categories:`)."
  @spec palette() :: keyword(keyword(String.t()))
  def palette, do: optional(:palette, [])

  @doc ~S|A page on the site, for the editor's hints: "/about" unless it says.|
  @spec example_path() :: String.t()
  def example_path, do: optional(:example_path, "/about")

  # An answer a hand-written site may leave out.
  defp optional(name, default) do
    site = get!()
    if exports?(site, name, 0), do: apply(site, name, []), else: default
  end

  defp answer!(name, example, naming) do
    call!(name, [], "Give it `use Billboard.Site`, with #{example}, naming #{naming}.") ||
      raise ArgumentError,
            "#{inspect(get!())} names no #{name}. Add #{example} to its " <>
              "`use Billboard.Site`, naming #{naming}"
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
