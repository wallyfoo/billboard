defmodule Billboard.ComponentCase do
  @moduledoc """
  Tests that a component works: in the palette, on the page, and in the
  editor. `mix billboard.gen.component` writes a test that uses it:

      defmodule MySite.Sections.FaqTest do
        use Billboard.ComponentCase, endpoint: MySiteWeb.Endpoint, repo: MySite.Repo

        test "the Faq section works on the page and in the editor" do
          assert_component_works(MySite.Sections.Faq)
        end
      end

  `assert_component_works/2` checks, against the configured site, that:

    1. the component is one the site lists, and some page may take it
       (`check_listed/2`);
    2. its placeholder builds, and no rule finds an error in it, on that
       page, after a hero when the site has one (`check_placeholder/2`);
    3. an item added to each of its lists, which starts as the list's
       part's blank, builds (`check_items/2`);
    4. it draws for a visitor, on its page, in the site's layout, with
       none of the editor's markup, or its renderer's `empty?/3` says it
       draws nothing (`check_visitor/2`);
    5. it draws open in the editor, its section editor beside it
       (`check_open/3`, which also runs the next two);
    6. every words entry is typed in place, but those its values hide
       (`check_words/3`);
    7. every other editor field draws its control in the section
       editor, but those hidden, and a select or variants the site
       narrows to fewer than two options (`check_fields/3`);
    8. its glyph, its sketch in the palette, draws (`check_glyph/2`).

  Each check is a function of its own, so a failing one can be run
  alone, and each failure says what's wrong and how to fix it. The open
  checks take the endpoint first: in a test that uses this module, it's
  `@endpoint`.

  `endpoint:` is the site's endpoint, which the open checks mount a
  LiveView on. `repo:`, when given, checks out the SQL sandbox for each
  test, as a site's `DataCase` does, for a layout or a section that
  reads the database. The LiveView shares the test's connection, so the
  tests run `async: false`. The open checks read the HTML with
  `Phoenix.LiveViewTest`, which needs `LazyHTML` among the site's test
  dependencies, as `mix phx.new` gives it.

  ## Options

  `assert_component_works/2`, and each check, take:

    * `attrs`: the content to build, for a component with no placeholder
      the palette can use, such as Shared, in place of the placeholder;
    * `data`: the section's data, for a component that draws rows, such
      as Reviews, in place of what the site's `Billboard.Data` gives it
      (`Billboard.Resolver.resolve/2`, read in the test's process);
    * `context`: the page's context (`Billboard.Context`);
    * `library`: the shared library's version, for Shared;
    * `children`: a Two columns section's two sections, which default
      to two of what a new Two columns holds in the editor
      (`Billboard.EditorLive.Palette.column_type/0`: Details, or the
      first component that fits a column);
    * `page`: the page to draw it on, by pattern, in place of the first
      the component may go on.
  """
  use ExUnit.CaseTemplate

  import ExUnit.Assertions

  alias Billboard.Catalogue.Entry
  alias Billboard.Component.Info
  alias Billboard.ComponentCase.Render
  alias Billboard.Sections.{EditorFields, Parts, Words}

  using opts do
    endpoint =
      Keyword.get(opts, :endpoint) ||
        raise ArgumentError,
              "`use Billboard.ComponentCase` needs the site's endpoint, which its open checks " <>
                "mount a LiveView on: `use Billboard.ComponentCase, endpoint: MySiteWeb.Endpoint`"

    if opts[:async] do
      raise ArgumentError,
            "#{inspect(__CALLER__.module)} uses Billboard.ComponentCase with `async: true`, but " <>
              "its open checks mount a LiveView, which shares the test's connection only when " <>
              "the test runs alone. Use `async: false`, or leave `async:` out"
    end

    unless Code.ensure_loaded?(LazyHTML) do
      raise ArgumentError,
            "Billboard.ComponentCase reads HTML with LazyHTML. Add `{:lazy_html, \">= 0.1.0\", " <>
              "only: :test}` to the site's deps, as `mix phx.new` does"
    end

    quote do
      @endpoint unquote(endpoint)
      @billboard_repo unquote(opts[:repo])
      import Billboard.ComponentCase, only: [assert_component_works: 1, assert_component_works: 2]

      setup tags do
        Billboard.ComponentCase.checkout(@billboard_repo, tags)
      end
    end
  end

  @doc false
  # `Billboard.Test.DataCase.setup_sandbox/1`'s, for the site's repo.
  def checkout(nil, _tags), do: :ok

  def checkout(repo, tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(repo, shared: not tags[:async])
    ExUnit.Callbacks.on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  @doc "Runs every check on `component`. See the moduledoc for the checks and `opts`."
  defmacro assert_component_works(component, opts \\ []) do
    quote do
      Billboard.ComponentCase.works!(@endpoint, unquote(component), unquote(opts))
    end
  end

  @doc false
  def works!(endpoint, component, opts) do
    check_listed(component, opts)
    check_placeholder(component, opts)
    check_items(component, opts)
    check_visitor(component, opts)
    check_open(endpoint, component, opts)
    check_glyph(component, opts)
    :ok
  end

  ## The checks

  @doc "Checks the component is one the site lists, and that a page the site has may take it."
  @spec check_listed(module(), keyword()) :: :ok
  def check_listed(component, opts \\ []) do
    key = key!(component)

    unless component in Billboard.Site.components() do
      flunk(
        "#{inspect(component)} isn't among the site's components. Add it to `components:` in " <>
          "#{inspect(Billboard.Site.get!())}'s `use Billboard.Site`."
      )
    end

    page!(component, key, opts)
    :ok
  end

  @doc """
  Checks the placeholder builds and that no rule, the component's own,
  the stock rules, or the site's, finds an error in its section, on its
  page, after a hero when the site has one.
  """
  @spec check_placeholder(module(), keyword()) :: :ok
  def check_placeholder(component, opts \\ []) do
    key = key!(component)
    section = build!(component, key, opts)
    page = page!(component, key, opts)
    section_key = section.key

    errors =
      for %{level: :error, key: ^section_key, message: message} <-
            Billboard.Rules.check(page, with_hero(section, key, page), %{}),
          do: message

    if errors != [] do
      flunk(
        "#{inspect(component)}'s placeholder breaks a rule on #{page_name(page)}: " <>
          Enum.join(errors, "; ") <>
          ". Change `placeholder` in its `component` section, or the rule, so a new section " <>
          "can be published."
      )
    end

    :ok
  end

  @doc """
  Checks that an item added to each of the component's lists builds: the
  editor adds one as the list's part's blank (`Billboard.Sections.Parts.blank/1`).
  """
  @spec check_items(module(), keyword()) :: :ok
  def check_items(component, opts \\ []) do
    key = key!(component)
    attrs = attrs(key, opts)

    for {field, spec} <- EditorFields.narrowed(key), spec[:as] == :list do
      part = list_part(spec[:part])
      blank = Parts.blank(part)
      items = List.duplicate(blank, max(spec[:min] || 1, 1))

      case Billboard.Component.build(key, Map.put(attrs, field, items)) do
        {:ok, _content} ->
          :ok

        {:error, error} ->
          flunk(
            "an item added to `#{field}` starts as the blank of #{inspect(part)} " <>
              "(#{inspect(blank)}), which #{inspect(component)} refuses: #{messages(error)}. " <>
              "Name the part the list holds in its `editor` entry (`part:`), or change the " <>
              "part's blank so it passes its validations."
          )
      end
    end

    :ok
  end

  @doc """
  Checks the component draws for a visitor, on its page, in the site's
  layout, with none of the editor's markup, or that its renderer's
  `empty?/3` says it draws nothing.
  """
  @spec check_visitor(module(), keyword()) :: :ok
  def check_visitor(component, opts \\ []) do
    key = key!(component)
    section = build!(component, key, opts)
    page = page!(component, key, opts)
    context = Keyword.get(opts, :context, %{})
    sections = with_hero(section, key, page)
    data = page_data(opts, section, sections)

    html =
      Render.page(sections,
        data: data,
        library: opts[:library],
        context: context
      )

    id = if key == :hero, do: "page-hero", else: Billboard.Section.dom_id(section)
    renderer = Billboard.Renderer.for!(key)

    drawn? = html =~ ~s(id="#{id}")
    empty? = Billboard.Sections.empty?(section, %{data: data, context: context, state: %{}})

    unless drawn? or empty? do
      flunk(
        "#{inspect(component)} draws nothing for a visitor, and its renderer doesn't say why. " <>
          "Draw its outer element with `id={@anchor}` in #{inspect(renderer)}.render/1, or " <>
          "give the renderer `empty?/3` for content that draws nothing."
      )
    end

    if html =~ "contenteditable" or html =~ "data-edit-section" do
      flunk(
        "#{inspect(component)} draws the editor's markup for a visitor. Draw its words " <>
          "through `Words.text/4`, which types in place only in the open section."
      )
    end

    :ok
  end

  @doc """
  Checks the section draws open in the editor, its section editor beside
  it, and then that its words are typed in place (`check_words/3`) and
  its other fields draw their controls (`check_fields/3`).
  """
  @spec check_open(module(), module(), keyword()) :: :ok
  def check_open(endpoint, component, opts \\ []) do
    open = open!(endpoint, component, opts)
    words!(open)
    fields!(open)
  end

  @doc """
  Checks that, open in the editor, every words entry the section's
  content has is typed in place: its own, its parts', and each list
  item's, but those its values hide (`hide_when`, and `bound: :hide`
  while its binding replaces them). Words offered under More are fields
  (`check_fields/3`).
  """
  @spec check_words(module(), module(), keyword()) :: :ok
  def check_words(endpoint, component, opts \\ []),
    do: endpoint |> open!(component, opts) |> words!()

  @doc """
  Checks that, open in the editor, every editor field but its words in
  place draws its control in the section editor, but those hidden, a
  select or variants the site narrows to fewer than two options, and a
  picker of a set of choices the site doesn't give.
  """
  @spec check_fields(module(), module(), keyword()) :: :ok
  def check_fields(endpoint, component, opts \\ []),
    do: endpoint |> open!(component, opts) |> fields!()

  @doc "Checks the component's glyph, its sketch in the palette, draws."
  @spec check_glyph(module(), keyword()) :: :ok
  def check_glyph(component, opts \\ []) do
    key = key!(component)

    if Render.glyph(build!(component, key, opts)) |> String.trim() == "" do
      flunk(
        "#{inspect(component)}'s glyph draws nothing, and the palette shows it. Draw a small " <>
          "sketch of the section in #{inspect(Billboard.Renderer.for!(key))}.glyph/1, from the " <>
          "editor's glyph utilities (`bg-bb-glyph-ink` and the rest)."
      )
    end

    :ok
  end

  ## Open in the editor

  # The section, drawn open in `Billboard.ComponentCase.EditorHost`.
  defp open!(endpoint, component, opts) do
    key = key!(component)
    section = build!(component, key, opts)
    page = page!(component, key, opts)

    sections = with_hero(section, key, page)

    session = %{
      "version" => Render.version(sections),
      "key" => section.key,
      "data" => page_data(opts, section, sections),
      "library" => opts[:library],
      "context" => Keyword.get(opts, :context, %{}),
      "path" => page.pattern
    }

    view =
      try do
        {:ok, view, _html} = mount_host(endpoint, session)
        view
      rescue
        error ->
          flunk(
            "#{inspect(component)} raises when its section is drawn open in the editor: " <>
              Exception.message(error) <>
              ". Draw it in #{inspect(Billboard.Renderer.for!(key))}.render/1 from what an " <>
              "open section's `ctx` holds (`Words.editing?/1` says when it's open)."
          )
      end

    unless Phoenix.LiveViewTest.has_element?(
             view,
             "#section-editor[data-section='#{section.key}']"
           ) do
      flunk(
        "#{inspect(component)}'s section doesn't open in the editor: its section editor isn't " <>
          "drawn. Draw the section through `Billboard.Sections.section/1`, which holds it."
      )
    end

    empty? =
      Billboard.Sections.empty?(section, %{
        data: session["data"],
        context: session["context"],
        state: %{}
      })

    %{view: view, component: component, key: key, section: section, empty?: empty?}
  end

  # `live_isolated/3` without `@endpoint`: in LiveView 1.1 the macro
  # expands to this call. If an upgrade moves it, make the open checks
  # macros that expand to `live_isolated/3` in the test module instead.
  defp mount_host(endpoint, session) do
    Phoenix.LiveViewTest.__isolated__(
      Phoenix.ConnTest.build_conn(),
      endpoint,
      Billboard.ComponentCase.EditorHost,
      session: session
    )
  end

  defp words!(%{view: view, component: component, key: key, section: section} = open) do
    missing =
      for path <- words_paths(EditorFields.narrowed(key), section.content.value, ""),
          stand_in_words?(open, path),
          not Phoenix.LiveViewTest.has_element?(view, "#" <> Words.id(section.key, path)),
          do: path

    if missing != [] do
      renderer = inspect(Billboard.Renderer.for!(key))

      flunk(
        Enum.map_join(missing, "\n", fn path ->
          "#{inspect(component)} names `#{path}` as words in its `editor`, but the open " <>
            "section types none in place there. Draw them with " <>
            "#{words_call(path)} in #{renderer}.render/1."
        end)
      )
    end

    :ok
  end

  # A section that draws nothing for its data is drawn open as a stand-in
  # with its head and introduction alone (`Billboard.Sections.section/1`),
  # so only those are typed in place.
  defp stand_in_words?(%{empty?: false}, _path), do: true

  defp stand_in_words?(%{empty?: true}, path),
    do: path == "intro" or String.starts_with?(path, "head.")

  # How a renderer draws the words at `path`: from `@content` at the top,
  # or from the item or part it's drawing, at the item's own path.
  defp words_call(path) do
    case String.split(path, ".") do
      [field] ->
        ~s|`Words.text(@ctx, "#{field}", @content.#{field})`|

      parts ->
        {holder, [field]} = Enum.split(parts, -1)

        holder =
          Enum.map_join(holder, ".", fn part ->
            if String.match?(part, ~r/^\d+$/), do: ~S|#{i}|, else: part
          end)

        ~s|`Words.text(@ctx, "#{holder}.#{field}", value)`, with the item's | <>
          "or part's `#{field}` as `value`,"
    end
  end

  defp fields!(%{view: view, component: component, key: key, section: section}) do
    specs = EditorFields.narrowed(key)
    content = section.content.value

    missing =
      for {field, spec} <- specs,
          not hidden?(spec, content),
          EditorFields.drawn?(spec),
          selector <- List.wrap(control(field, spec, section, content)),
          not Phoenix.LiveViewTest.has_element?(view, selector),
          do: {field, spec, selector}

    missing =
      case ground(section) do
        nil -> missing
        selector -> missing ++ ground_missing(view, selector)
      end

    case missing do
      [] ->
        :ok

      [{:surface, nil, selector} | _rest] ->
        flunk(
          "#{inspect(component)}'s section may choose its ground among the site's surfaces, " <>
            "but the section editor draws no Ground (#{selector}). Check its component's " <>
            "`surface_kind` and `surface_from`."
        )

      [{field, spec, selector} | _rest] ->
        flunk(
          "#{inspect(component)}'s `editor` names `#{field}` (#{spec[:as] || :text}), but the " <>
            "section editor draws no control for it (#{selector}). Check its entry's options, " <>
            "such as `options:` for a select, `part:` for a list, and `from:` for a choice."
        )
    end
  end

  defp ground_missing(view, selector) do
    if Phoenix.LiveViewTest.has_element?(view, selector),
      do: [],
      else: [{:surface, nil, selector}]
  end

  # Each words path the content has: the component's own words, its
  # parts' (`head.heading`), and each list item's (`questions.0.title`),
  # but those hidden under the content's values. A button's and a link's
  # words are changed in their popover, not typed in place, so they're
  # not words here. Words with `more: true` aren't typed in place: the
  # section editor draws them as inputs under More (`#section-more`), so
  # they're checked as fields.
  defp words_paths(specs, content, prefix) do
    Enum.flat_map(specs, fn {field, spec} ->
      value = content && Map.get(content, field)

      cond do
        hidden?(spec, content) ->
          []

        words?(spec) ->
          [prefix <> to_string(field)]

        list_part(spec[:part]) in [:action, :link] ->
          []

        spec[:as] == :part and not is_nil(value) ->
          words_paths(Parts.editor_fields(spec[:part]), value, "#{prefix}#{field}.")

        spec[:as] == :list and is_list(value) ->
          value
          |> Enum.with_index()
          |> Enum.flat_map(fn {item, i} ->
            words_paths(Parts.editor_fields(spec[:part]), item, "#{prefix}#{field}.#{i}.")
          end)

        true ->
          []
      end
    end)
  end

  # A stock part's words have no `as`; a component's and a site part's
  # are `as: :text` or `:markdown`.
  defp words?(spec), do: spec[:as] in [nil, :text, :markdown] and not EditorFields.more?(spec)

  # `EditorFields.hidden?/2`, on the content rather than its form.
  defp hidden?(spec, content) do
    hidden_by_value? =
      Enum.any?(spec[:hide_when] || [], fn {field, values} ->
        to_string(Map.get(content, field)) in Enum.map(values, &to_string/1)
      end)

    hidden_by_binding? =
      spec[:bound] == :hide and Billboard.Context.replaces_words?(Map.get(content, :bind))

    hidden_by_value? or hidden_by_binding?
  end

  # The selector of what the section editor, or the open section, draws
  # for an entry, as `Billboard.EditorLive.SectionEditor` and
  # `EditorFields.setting/1` draw it, or nil for one with no control of
  # its own: words typed in place, checked as words, and a required part,
  # whose words are.
  defp control(field, spec, section, content) do
    key = section.key

    case spec[:as] do
      # The controls header's settings. Several choices sit behind their
      # popover's button.
      :choices ->
        if given?(spec), do: "#section-groups"

      :choice ->
        if given?(spec), do: "#section-setting-#{field}"

      as when as in [:select, :toggle, :number, :shared] ->
        "#section-setting-#{field}"

      :variants ->
        Enum.map(spec[:options], &"#section-variant-#{&1}")

      :note ->
        "[id^='section-note']"

      # A binding's note is drawn only while the binding says something.
      :binding_note ->
        if binding_note?(content), do: "[id^='section-note']"

      # Words under More are inputs named for the field.
      as when as in [nil, :text, :markdown] ->
        if EditorFields.more?(spec), do: "#section-more [name$='[#{field}]']"

      :list ->
        list_control(field, spec, content)

      :part ->
        part_control(field, spec, content)

      :photo ->
        "#photo-form-#{key}"

      _other ->
        nil
    end
  end

  # A list adds its items from the header, but a list of buttons, which
  # its renderer adds to (`Parts.add_button/1`). A full list adds none.
  defp list_control(field, spec, content) do
    count = length(Map.get(content, field) || [])

    cond do
      count >= Keyword.get(spec, :max, 12) -> nil
      list_part(spec[:part]) == :action -> "#section-add-button-#{Words.dashed("#{field}")}"
      true -> "#section-add-#{field}"
    end
  end

  # A part the section can do without is added from the header, and taken
  # away under More, but a button, which the open section adds and opens.
  defp part_control(field, spec, content) do
    present? = not is_nil(Map.get(content, field))

    cond do
      !spec[:optional] -> nil
      spec[:part] == :action and present? -> "#section-at-#{field}"
      spec[:part] == :action -> "#section-add-button-#{field}"
      present? -> "#section-drop-#{field}"
      true -> "#section-add-#{field}"
    end
  end

  # A picker of a set of choices the site doesn't give draws nothing, as
  # `Billboard.Context.choices_for/1` leaves the set out.
  defp given?(spec), do: spec[:from] in Billboard.Context.choice_sets()

  defp binding_note?(content) do
    case Billboard.Context.binding_for(Map.get(content, :bind)) do
      {_name, opts} -> is_binary(opts[:note])
      nil -> false
    end
  end

  # The section's own ground, which the header draws when the section
  # chooses its own surface and the site offers its kind more than one.
  defp ground(%{content: %{type: type}}) do
    if Billboard.Surfaces.choosable?(type, nil) and
         match?([_, _ | _], Billboard.Surfaces.offered(Billboard.Surfaces.kind(type))),
       do: "#section-setting-surface"
  end

  ## Building the section

  defp key!(component) do
    unless Info.component?(component) do
      flunk(
        "#{inspect(component)} isn't a billboard component. Give it `use Billboard.Component`."
      )
    end

    Info.component_key!(component)
  end

  defp attrs(key, opts),
    do: Keyword.get_lazy(opts, :attrs, fn -> Billboard.SiteOptions.placeholder(key) end)

  defp build!(component, key, opts) do
    unless component in Billboard.Site.components() do
      flunk(
        "#{inspect(component)} isn't among the site's components, so it can't be built. " <>
          "Add it to `components:` in #{inspect(Billboard.Site.get!())}'s `use Billboard.Site`."
      )
    end

    attrs = attrs(key, opts)

    case Billboard.Component.build(key, attrs) do
      {:ok, _content} ->
        key |> Render.section(attrs, "s1") |> with_children(component, key, opts)

      {:error, error} ->
        flunk(
          "#{inspect(component)}'s placeholder doesn't build: #{messages(error)}. " <>
            "Change `placeholder` in its `component` section so it passes the component's " <>
            "validations, or give `assert_component_works/2` the `attrs:` to build."
        )
    end
  end

  # A Two columns section holds two sections: `children:`, or two of what
  # a new Two columns arrives holding in the editor, from its placeholder.
  defp with_children(section, component, :columns, opts) do
    children =
      Keyword.get_lazy(opts, :children, fn ->
        case Billboard.EditorLive.Palette.column_type() do
          nil ->
            flunk(
              "#{inspect(component)} holds two sections, and none of the site's components " <>
                "fits in a column. Give `assert_component_works/2` the two as `children:`, " <>
                "or give a component `column? true`."
            )

          type ->
            placeholder = Billboard.SiteOptions.placeholder(type)
            [Render.section(type, placeholder, "s2"), Render.section(type, placeholder, "s3")]
        end
      end)

    children = children |> Enum.with_index() |> Enum.map(fn {c, i} -> %{c | position: i} end)
    %{section | children: children}
  end

  defp with_children(section, _component, _key, _opts), do: section

  # The page holds a hero first, as every page but the library does when
  # the site has one.
  defp with_hero(section, :hero, _page), do: [section]
  defp with_hero(section, _key, %{kind: :library}), do: [section]

  defp with_hero(section, _key, _page) do
    if :hero in Billboard.Catalogue.keys(),
      do: [Render.section(:hero, Billboard.SiteOptions.placeholder(:hero), "hero"), section],
      else: [section]
  end

  # The page `opts[:page]` names, or the first of the site's pages whose
  # kind the component may go on, but a fixed page that doesn't list it.
  defp page!(component, key, opts) do
    case Keyword.fetch(opts, :page) do
      {:ok, pattern} ->
        Billboard.Directory.fetch(pattern) ||
          flunk(
            "the site has no page #{inspect(pattern)}, which `page:` names. Name one of its " <>
              "`pages`: #{Enum.map_join(Billboard.Directory.pages(), ", ", &inspect(&1.pattern))}."
          )

      :error ->
        entry = Billboard.Catalogue.fetch!(key)

        Enum.find(Billboard.Directory.pages(), fn page ->
          Entry.allows?(entry, page.kind) and (not is_list(page.fixed) or key in page.fixed)
        end) ||
          flunk(
            "no page the site lists may take #{inspect(component)}: its kinds are " <>
              "#{inspect(entry.kinds)}. Add a page of one of those kinds to `pages`, or widen " <>
              "`kinds:` in `use Billboard.Site`."
          )
    end
  end

  defp page_name(%{pattern: nil}), do: "the library"
  defp page_name(%{pattern: pattern}), do: pattern

  defp list_part({part, _except}), do: part
  defp list_part(part), do: part

  # The page's data, by section key: `data:` for the section, or what the
  # site's `Billboard.Data` gives the page's sections, read here, in the
  # test's own process, as `Billboard.Resolver` reads it for a page.
  defp page_data(opts, section, sections) do
    case Keyword.fetch(opts, :data) do
      {:ok, rows} ->
        %{section.key => rows}

      :error ->
        Billboard.Resolver.resolve(%{sections: sections}, Keyword.get(opts, :context, %{}))
    end
  end

  # The error's messages, in the words a validation gives them, joined.
  defp messages(%{errors: [_ | _] = errors}),
    do: errors |> Enum.map(&message/1) |> Enum.uniq() |> Enum.join("; ")

  defp messages(error), do: message(error)

  defp message(%{message: message} = error) when is_binary(message) do
    vars = Map.get(error, :vars) || []

    vars
    |> Enum.reduce(message, fn {name, value}, message ->
      String.replace(message, "%{#{name}}", show(value))
    end)
    |> sentence()
  end

  # An Ash error's message leads with where it came from ("Bread Crumbs:"),
  # which says nothing a component's author can act on.
  defp message(error) when is_exception(error) do
    error
    |> Exception.message()
    |> String.split("\n")
    |> Enum.reject(
      &(String.trim(&1) in ["", "Bread Crumbs:"] or String.starts_with?(String.trim(&1), ">"))
    )
    |> Enum.join(" ")
    |> sentence()
  end

  defp message(error), do: inspect(error)

  defp show(value) when is_binary(value), do: value
  defp show(value) when is_atom(value) or is_number(value), do: to_string(value)
  defp show(value), do: inspect(value)

  defp sentence(message), do: message |> String.trim() |> String.trim_trailing(".")
end
