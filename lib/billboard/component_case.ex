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
    2. its placeholder builds, and no rule finds an error on its page,
       after a hero when the site has one, that the page doesn't have
       without it (`check_placeholder/2`);
    3. an item added to each of its lists, which starts as the list's
       part's blank, and each part it can do without, added as its blank,
       build (`check_items/2`);
    4. it draws for a visitor, on its page, in the site's layout, with
       its words as they're written and none of the editor's markup, or
       its renderer's `empty?/3` says it draws nothing (`check_visitor/2`);
    5. it draws open in the editor, its section editor beside it
       (`check_open/2`, which also runs the next two);
    6. every words entry is typed in place, holding its words, but those
       its values hide (`check_words/2`);
    7. every other editor field draws its control, but those hidden,
       and a select or variants the site narrows to fewer than two
       options: in the section editor, or, for an item's tools, a
       button, and a photograph's tools, in the open section
       (`check_fields/2`);
    8. its glyph, its sketch in the palette, draws (`check_glyph/2`).

  Each check can be run alone, and each failure says what's wrong and
  how to fix it. The open checks are macros: they mount the editor with
  `Phoenix.LiveViewTest.live_isolated/3`, expanded in the test's module,
  on its `@endpoint`, and `use Billboard.ComponentCase` requires this
  module for them.

  `endpoint:` is the site's endpoint, which the open checks mount a
  LiveView on. `repo:`, when given, checks out the SQL sandbox for each
  test, as a site's `DataCase` does, for a layout or a section that
  reads the database. The LiveView shares the test's connection, so the
  tests run `async: false`. The checks read the HTML with `LazyHTML`,
  which needs to be among the site's test dependencies, as `mix phx.new`
  gives it.

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

  # LazyHTML is a site's test dependency, which `using` checks for.
  @compile {:no_warn_undefined, LazyHTML}

  alias Billboard.Catalogue.Entry
  alias Billboard.Component.Info
  alias Billboard.ComponentCase.Render
  alias Billboard.Markdown
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
      require Billboard.ComponentCase
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
      Billboard.ComponentCase.works!(unquote(component), unquote(opts), unquote(mount()))
    end
  end

  @doc """
  Checks the section draws open in the editor, its section editor beside
  it, and then that its words are typed in place (`check_words/2`) and
  its other fields draw their controls (`check_fields/2`). A macro, which
  mounts the editor on the test module's `@endpoint`.
  """
  defmacro check_open(component, opts \\ []) do
    quote do
      Billboard.ComponentCase.open_checks!(
        [:words, :fields],
        unquote(component),
        unquote(opts),
        unquote(mount())
      )
    end
  end

  @doc """
  Checks that, open in the editor, every words entry the section's
  content has is typed in place, holding its words: its own, its parts',
  and each list item's, but those its values hide (`hide_when`, and
  `bound: :hide` while its binding replaces them). Words offered under
  More are fields (`check_fields/2`). A macro, as `check_open/2` is.
  """
  defmacro check_words(component, opts \\ []) do
    quote do
      Billboard.ComponentCase.open_checks!(
        [:words],
        unquote(component),
        unquote(opts),
        unquote(mount())
      )
    end
  end

  @doc """
  Checks that, open in the editor, every editor field but its words in
  place draws its control, but those hidden, a select or variants the
  site narrows to fewer than two options, and a picker of a set of
  choices the site doesn't give. The section editor draws most; the open
  section's renderer draws an item's tools (`Parts.item_tools/1`), a
  button's mark and the way to add one (`Parts.editable_action/1` and
  `Parts.add_button/1`), and a photograph's tools
  (`Parts.editable_photo/1`). A macro, as `check_open/2` is.
  """
  defmacro check_fields(component, opts \\ []) do
    quote do
      Billboard.ComponentCase.open_checks!(
        [:fields],
        unquote(component),
        unquote(opts),
        unquote(mount())
      )
    end
  end

  # Mounts the editor's host with the session the open checks build:
  # `live_isolated/3`, expanded in the test module, so it reads that
  # module's `@endpoint`.
  defp mount do
    quote do
      fn session ->
        require Phoenix.LiveViewTest

        Phoenix.LiveViewTest.live_isolated(
          Phoenix.ConnTest.build_conn(),
          Billboard.ComponentCase.EditorHost,
          session: session
        )
      end
    end
  end

  @doc false
  def works!(component, opts, mount) do
    check_listed(component, opts)
    check_placeholder(component, opts)
    check_items(component, opts)
    check_visitor(component, opts)
    open_checks!([:words, :fields], component, opts, mount)
    check_glyph(component, opts)
    :ok
  end

  @doc false
  # The open checks, on one mount of the editor's host by `mount`.
  def open_checks!(checks, component, opts, mount) do
    open = open!(component, opts, mount)
    if :words in checks, do: words!(open)
    if :fields in checks, do: fields!(open)
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
  Checks the placeholder builds, or the `attrs` given, and that no rule,
  the component's own, the stock rules, or the site's, finds an error on
  its page, after a hero when the site has one, that the page doesn't
  have without it: about the section, about the page, or about a section
  inside it.
  """
  @spec check_placeholder(module(), keyword()) :: :ok
  def check_placeholder(component, opts \\ []) do
    key = key!(component)
    section = build!(component, key, opts)
    page = page!(component, key, opts)
    sections = with_hero(section, key, page)

    errors = rule_errors(page, sections) -- rule_errors(page, List.delete(sections, section))

    if errors != [] do
      flunk(
        "#{built_from(component, opts)} breaks a rule on #{page_name(page)}: " <>
          Enum.map_join(errors, "; ", &elem(&1, 1)) <> ". " <> rule_fix(opts)
      )
    end

    :ok
  end

  # The page's errors, each with the key of the section it's about, or
  # nil for the page.
  defp rule_errors(page, sections) do
    for %{level: :error, key: key, message: message} <-
          Billboard.Rules.check(page, sections, %{}),
        do: {key, message}
  end

  defp built_from(component, opts) do
    if Keyword.has_key?(opts, :attrs),
      do: "#{inspect(component)}, built from the `attrs:` given,",
      else: "#{inspect(component)}'s placeholder"
  end

  defp rule_fix(opts) do
    if Keyword.has_key?(opts, :attrs),
      do: "Change the `attrs:`, or the rule, so the section can be published.",
      else:
        "Change `placeholder` in its `component` section, or the rule, so a new section " <>
          "can be published."
  end

  @doc """
  Checks that what the editor adds builds: an item added to each of the
  component's lists, after the items the placeholder (or `attrs`) holds,
  or in place of its last when the list is full, and each part the
  component can do without, in its place. Each starts as its part's
  blank (`Billboard.Sections.Parts.blank/1`), as the editor adds it.
  """
  @spec check_items(module(), keyword()) :: :ok
  def check_items(component, opts \\ []) do
    key = key!(component)
    attrs = attrs(key, opts)

    for {field, spec} <- EditorFields.narrowed(key),
        {kind, blank, value} <- added(field, spec, attrs) do
      case Billboard.Component.build(key, Map.put(attrs, field, value)) do
        {:ok, _content} -> :ok
        {:error, error} -> flunk(added_message(kind, component, field, spec, blank, error))
      end
    end

    :ok
  end

  # What the editor adds at `field`: an item after the list's, or, when
  # it's full, in place of its last; or a part the section can do
  # without.
  defp added(field, spec, attrs) do
    cond do
      spec[:as] == :list ->
        blank = Parts.blank(spec[:part])
        items = given(attrs, field) || []

        items =
          if length(items) < Keyword.get(spec, :max, 12),
            do: items ++ [blank],
            else: List.replace_at(items, -1, blank)

        [{:item, blank, items}]

      spec[:as] == :part and spec[:optional] ->
        blank = Parts.blank(spec[:part])
        [{:part, blank, blank}]

      true ->
        []
    end
  end

  defp given(attrs, field), do: Map.get(attrs, field, Map.get(attrs, to_string(field)))

  defp added_message(:item, component, field, spec, blank, error) do
    "an item added to `#{field}` starts as the blank of #{inspect(list_part(spec[:part]))} " <>
      "(#{inspect(blank)}), which #{inspect(component)} refuses: #{messages(error)}. " <>
      "Name the part the list holds in its `editor` entry (`part:`), or change the " <>
      "part's blank so it passes its validations."
  end

  defp added_message(:part, component, field, spec, blank, error) do
    "a `#{field}` added to #{inspect(component)} starts as the blank of " <>
      "#{inspect(list_part(spec[:part]))} (#{inspect(blank)}), which it refuses: " <>
      "#{messages(error)}. Name the part it holds in its `editor` entry (`part:`), or " <>
      "change the part's blank so it passes its validations."
  end

  @doc """
  Checks the component draws for a visitor, on its page, in the site's
  layout, with its words as they're written and none of the editor's
  markup, or that its renderer's `empty?/3` says it draws nothing. A
  hero must draw something inside the page's hero block.
  """
  @spec check_visitor(module(), keyword()) :: :ok
  def check_visitor(component, opts \\ []) do
    key = key!(component)
    section = build!(component, key, opts)
    page = page!(component, key, opts)
    renderer = Billboard.Renderer.for!(key)
    context = Keyword.get(opts, :context, %{})
    sections = with_hero(section, key, page)

    {data, html} =
      drawing(component, renderer, :visitor, fn ->
        data = page_data(opts, section, sections)

        {data, Render.page(sections, data: data, library: opts[:library], context: context)}
      end)

    doc = LazyHTML.from_fragment(html)
    ctx = draw_ctx(data, context, opts[:library])
    id = drawn_id(section, key, ctx)
    element = if is_binary(id), do: LazyHTML.query_by_id(doc, id)
    drawn? = element != nil and Enum.count(element) > 0
    empty? = Billboard.Sections.empty?(section, ctx)

    unless drawn? or empty? do
      flunk(
        "#{inspect(component)} draws nothing for a visitor, and its renderer doesn't say why. " <>
          "Draw its outer element with `id={@anchor}` in #{inspect(renderer)}.render/1, or " <>
          "give the renderer `empty?/3` for content that draws nothing."
      )
    end

    editor_markup!(component, renderer, doc)

    if drawn? and not empty? do
      hero_drawn!(component, key, renderer, doc)
      visitor_words!(component, key, renderer, section, element)
    end

    :ok
  end

  defp editor_markup!(component, renderer, doc) do
    cond do
      has?(doc, "[contenteditable], [data-edit-section]") ->
        flunk(
          "#{inspect(component)} draws the editor's markup for a visitor. Draw its words " <>
            "through `Words.text/4`, which types in place only in the open section."
        )

      has?(doc, "[data-editor-ui], [data-edit-action]") ->
        flunk(
          "#{inspect(component)} draws the editor's own controls for a visitor. Guard " <>
            "`Parts.add_button/1` and `Parts.item_tools/1` with `Words.editing?(@ctx)` in " <>
            "#{inspect(renderer)}.render/1, as `<Parts.item_tools :if={Words.editing?(@ctx)} " <>
            "… />`, so they're drawn only in the open section."
        )

      true ->
        :ok
    end
  end

  # The page draws the hero block's `<section>`, so a hero's renderer
  # that draws nothing leaves it empty.
  defp hero_drawn!(component, :hero, renderer, doc) do
    unless has?(doc, "#page-hero > *") do
      flunk(
        "#{inspect(component)} draws nothing in the page's hero block (#page-hero) for a " <>
          "visitor. Draw the hero's heading, and the rest of it, in " <>
          "#{inspect(renderer)}.render/1: the page draws the block round what it draws."
      )
    end
  end

  defp hero_drawn!(_component, _key, _renderer, _doc), do: :ok

  # A visitor sees the section's plain words as they're written.
  defp visitor_words!(component, key, renderer, section, element) do
    text = element |> LazyHTML.text() |> squish()

    missing =
      for {path, value} <- words_paths(EditorFields.narrowed(key), section.content.value, ""),
          plain?(value),
          not shows?(text, value),
          do: {path, value}

    if missing != [] do
      flunk(
        Enum.map_join(missing, "\n", fn {path, value} ->
          "#{inspect(component)}'s `#{path}` holds #{inspect(value)}, but a visitor doesn't " <>
            "see it: its section draws no such words. Draw them with #{words_call(path)} " <>
            "in #{inspect(renderer)}.render/1, which shows a visitor the words as written."
        end)
      )
    end
  end

  @doc "Checks the component's glyph, its sketch in the palette, draws an element or more."
  @spec check_glyph(module(), keyword()) :: :ok
  def check_glyph(component, opts \\ []) do
    key = key!(component)
    section = build!(component, key, opts)
    renderer = Billboard.Renderer.for!(key)
    html = drawing(component, renderer, :glyph, fn -> Render.glyph(section) end)

    unless has?(LazyHTML.from_fragment(html), "*") do
      flunk(
        "#{inspect(component)}'s glyph draws nothing, not one element, and the palette shows " <>
          "it. Draw a small sketch of the section in #{inspect(renderer)}.glyph/1, from the " <>
          "editor's glyph utilities (`bg-bb-glyph-ink` and the rest)."
      )
    end

    :ok
  end

  ## What raises

  # Draws with `draw`, and flunks, naming what to fix, if it raises.
  defp drawing(component, renderer, where, draw) do
    draw.()
  rescue
    error -> flunk(raised(component, renderer, where, error, __STACKTRACE__))
  end

  # What a raise while drawing says: the test's setup for a database read
  # without a connection, the renderer when it's in the stacktrace, and
  # otherwise what else the page draws.
  defp raised(component, renderer, where, error, stacktrace) do
    cond do
      ownership?(error) ->
        "#{inspect(component)}'s section reads the database when it's drawn " <>
          "#{where_words(where)}, but the test holds no connection for it " <>
          "(#{first_line(error)}). Pass the site's repo, as `use Billboard.ComponentCase, " <>
          "endpoint: …, repo: MySite.Repo`, which checks out the SQL sandbox for each test."

      Enum.any?(stacktrace, &match?({^renderer, _function, _arity, _location}, &1)) ->
        "#{inspect(component)} raises when its section is drawn #{where_words(where)}: " <>
          "#{message(error)}. #{raise_fix(where, renderer)}"

      true ->
        "drawing #{inspect(component)}'s section #{where_words(where)} raised outside its " <>
          "renderer#{frame(stacktrace)}: #{message(error)}. Check what the page reads besides " <>
          "the section: the site's layout and `Billboard.Data`, and the `context:`, `data:`, " <>
          "and `library:` given."
    end
  end

  defp where_words(:visitor), do: "for a visitor"
  defp where_words(:open), do: "open in the editor"
  defp where_words(:glyph), do: "as its glyph, in the palette"

  defp raise_fix(:visitor, renderer),
    do: "Draw it in #{inspect(renderer)}.render/1 from what a visitor's `ctx` holds."

  defp raise_fix(:open, renderer) do
    "Draw it in #{inspect(renderer)}.render/1 from what an open section's `ctx` holds " <>
      "(`Words.editing?/1` says when it's open)."
  end

  defp raise_fix(:glyph, renderer),
    do: "Draw #{inspect(renderer)}.glyph/1 from its `section` and `content` alone."

  defp ownership?(error) do
    match?(%{__struct__: DBConnection.OwnershipError}, error) or
      Exception.message(error) =~ "cannot find ownership process"
  end

  defp first_line(error),
    do: error |> Exception.message() |> String.split("\n", trim: true) |> hd() |> sentence()

  defp frame([{module, function, arity, _location} | _rest]) do
    arity = if is_list(arity), do: length(arity), else: arity
    " (in #{inspect(module)}.#{function}/#{arity})"
  end

  defp frame(_stacktrace), do: ""

  ## Open in the editor

  # The section, drawn open in `Billboard.ComponentCase.EditorHost`,
  # mounted by `mount`, and the HTML it draws.
  defp open!(component, opts, mount) do
    key = key!(component)
    section = build!(component, key, opts)
    page = page!(component, key, opts)
    renderer = Billboard.Renderer.for!(key)
    sections = with_hero(section, key, page)

    session = %{
      "version" => Render.version(sections),
      "key" => section.key,
      "data" => drawing(component, renderer, :open, fn -> page_data(opts, section, sections) end),
      "library" => opts[:library],
      "context" => Keyword.get(opts, :context, %{}),
      "path" => page.pattern
    }

    view = mount!(mount, session, component, renderer)
    doc = view |> Phoenix.LiveViewTest.render() |> LazyHTML.from_fragment()

    unless has?(doc, "#section-editor[data-section='#{section.key}']") do
      flunk(
        "#{inspect(component)}'s section doesn't open in the editor: its section editor isn't " <>
          "drawn. Draw the section through `Billboard.Sections.section/1`, which holds it."
      )
    end

    empty? =
      Billboard.Sections.empty?(
        section,
        draw_ctx(session["data"], session["context"], opts[:library])
      )

    %{
      doc: doc,
      component: component,
      key: key,
      renderer: renderer,
      section: section,
      empty?: empty?
    }
  end

  # `Phoenix.LiveViewTest` draws the page in the test's process first, so
  # a raise there is rescued; a raise in the LiveView's own process stops
  # it, and the mount exits with the raise as its reason.
  defp mount!(mount, session, component, renderer) do
    result =
      try do
        mount.(session)
      rescue
        error -> {:raised, error, __STACKTRACE__}
      catch
        :exit, {{error, stacktrace}, _where} when is_exception(error) ->
          {:raised, error, stacktrace}

        :exit, reason ->
          {:exited, reason}
      end

    case result do
      {:ok, view, _html} ->
        view

      {:raised, error, stacktrace} ->
        flunk(raised(component, renderer, :open, error, stacktrace))

      {:exited, reason} ->
        flunk(
          "the editor's host stopped while drawing #{inspect(component)}'s section open: " <>
            "#{inspect(reason)}. Check `use Billboard.ComponentCase`'s `endpoint:`, the site's " <>
            "endpoint, and `repo:`, its repo, for a section or layout that reads the database."
        )

      other ->
        flunk(
          "the editor's host didn't mount #{inspect(component)}'s section open: " <>
            "#{inspect(other)}. Check `use Billboard.ComponentCase`'s `endpoint:`, which " <>
            "should be the site's endpoint."
        )
    end
  end

  defp words!(%{doc: doc, component: component, key: key, section: section} = open) do
    problems =
      for {path, value} <- words_paths(EditorFields.narrowed(key), section.content.value, ""),
          stand_in?(open, path),
          problem <- words_problem(open, doc, path, value),
          do: problem

    if problems != [] do
      flunk(
        Enum.map_join(problems, "\n", fn
          {:missing, path} ->
            "#{inspect(component)} names `#{path}` as words in its `editor`, but the open " <>
              "section types none in place there. Draw them with " <>
              "#{words_call(path)} in #{inspect(open.renderer)}.render/1."

          {:other, path, value, text} ->
            "#{inspect(component)}'s open section types `#{path}` in place, but not its " <>
              "words: it holds #{inspect(text)} where the content holds #{inspect(value)}. " <>
              "Draw the field's own value, with #{words_call(path)} in " <>
              "#{inspect(open.renderer)}.render/1."
        end)
      )
    end

    :ok
  end

  defp words_problem(%{section: section}, doc, path, value) do
    element = LazyHTML.query_by_id(doc, Words.id(section.key, path))
    text = element |> LazyHTML.text() |> squish()

    cond do
      Enum.count(element) == 0 -> [{:missing, path}]
      plain?(value) and not shows?(text, value) -> [{:other, path, value, text}]
      true -> []
    end
  end

  # A section that draws nothing for its data is drawn open as a stand-in
  # with its head and introduction alone (`Billboard.Sections.section/1`),
  # so only those, and the head's button, are drawn.
  defp stand_in?(%{empty?: false}, _path), do: true

  defp stand_in?(%{empty?: true}, path),
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

  # Words that read as they're written, which a visitor and the open
  # section show as they are, or with Markdown's typography
  # (`Billboard.Markdown.plain/1`): on one line, and with no Markdown.
  defp plain?(value) do
    is_binary(value) and String.trim(value) != "" and
      not String.contains?(value, ["\n", "*", "_", "`", "[", "]", "<", ">", "\\", "&"])
  end

  defp shows?(text, value),
    do:
      String.contains?(text, squish(value)) or
        String.contains?(text, squish(Markdown.plain(value)))

  defp squish(text), do: text |> String.replace(~r/\s+/u, " ") |> String.trim()

  defp has?(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count() > 0

  defp fields!(%{doc: doc, component: component, key: key, section: section} = open) do
    specs = EditorFields.narrowed(key)
    content = section.content.value

    header =
      for {field, spec} <- specs,
          not hidden?(spec, content),
          EditorFields.drawn?(spec),
          selector <- List.wrap(control(field, spec, section, content)),
          not has?(doc, selector),
          do: field_message(component, field, spec, selector)

    ground =
      case ground(section) do
        nil ->
          []

        selector ->
          if has?(doc, selector), do: [], else: [ground_message(component, selector)]
      end

    drawn =
      for {kind, path, selector} <- drawn_controls(specs, content, ""),
          stand_in?(open, path),
          not has?(doc, selector),
          do: drawn_message(open, kind, path, selector)

    case header ++ ground ++ drawn do
      [] -> :ok
      messages -> flunk(Enum.join(messages, "\n"))
    end
  end

  defp field_message(component, field, spec, selector) do
    "#{inspect(component)}'s `editor` names `#{field}` (#{spec[:as] || :text}), but the " <>
      "section editor draws no control for it (#{selector}). Check its entry's options, " <>
      "such as `options:` for a select, `part:` for a list, and `from:` for a choice."
  end

  defp ground_message(component, selector) do
    "#{inspect(component)}'s section may choose its ground among the site's surfaces, " <>
      "but the section editor draws no Ground (#{selector}). Check its component's " <>
      "`surface_kind` and `surface_from`."
  end

  defp drawn_message(%{component: component, renderer: renderer}, :item_tools, path, selector) do
    {list, index} = split_index(path)

    "#{inspect(component)}'s open section draws no tools for item #{index} of `#{list}` " <>
      "(#{selector}), to remove and move it. Draw `Parts.item_tools/1` in each item while " <>
      "the section is open, in #{inspect(renderer)}.render/1: `<Parts.item_tools " <>
      ~s|:if={Words.editing?(@ctx)} path="#{list}" index={i} count={…} spec={…} />`.|
  end

  defp drawn_message(open, :editable_action, path, selector) do
    "#{inspect(open.component)}'s open section draws the button at `#{path}` without the " <>
      "editor's mark (#{selector}), so a click on it follows it instead of opening its " <>
      "popover. " <> action_fix(open, path, :editable_action)
  end

  defp drawn_message(open, :add_button, path, selector) do
    "#{inspect(open.component)}'s open section offers no way to add a button at `#{path}` " <>
      "(#{selector}). " <> action_fix(open, path, :add_button)
  end

  defp drawn_message(%{component: component, renderer: renderer}, :photo_tools, path, selector) do
    "#{inspect(component)}'s open section draws no tools over its photograph `#{path}` " <>
      "(#{selector}), to put one in, describe it, or take it away. Draw the photograph " <>
      "inside `Parts.editable_photo/1` in #{inspect(renderer)}.render/1."
  end

  # A head's button is `Parts.head/1`'s to draw; any other is the
  # renderer's, alone or in a row of them.
  defp action_fix(_open, "head." <> _rest, _kind),
    do: "Draw the head with `Parts.head/1`, which draws its button for the editor."

  defp action_fix(%{renderer: renderer}, path, :editable_action) do
    "Draw `Parts.editable_action/1` round it while the section is open, in " <>
      "#{inspect(renderer)}.render/1: " <>
      ~s|`<Parts.editable_action ctx={@ctx} path="#{path}">…</Parts.editable_action>`, | <>
      "or draw a list of buttons with `Parts.action_group/1`."
  end

  defp action_fix(%{renderer: renderer}, path, :add_button) do
    "Draw `Parts.add_button/1` while the section is open, in #{inspect(renderer)}.render/1: " <>
      ~s|`<Parts.add_button :if={Words.editing?(@ctx) && …} path="#{path}" />`, | <>
      "or draw a list of buttons with `Parts.action_group/1`, which offers one."
  end

  defp split_index(path) do
    {list, [index]} = path |> String.split(".") |> Enum.split(-1)
    {Enum.join(list, "."), index}
  end

  # Each words path the content has, with the words it holds: the
  # component's own words, its parts' (`head.heading`), and each list
  # item's (`questions.0.title`), but those hidden under the content's
  # values. A button's and a link's words are changed in their popover,
  # not typed in place, so they're not words here. Words with
  # `more: true` aren't typed in place: the section editor draws them as
  # inputs under More (`#section-more`), so they're checked as fields.
  defp words_paths(specs, content, prefix) do
    Enum.flat_map(specs, fn {field, spec} ->
      value = content && Map.get(content, field)

      cond do
        hidden?(spec, content) ->
          []

        words?(spec) ->
          [{prefix <> to_string(field), value}]

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

  # The controls the open section's renderer draws, through `Parts`, for
  # the editor, as `{kind, path, selector}`: each item's tools, each
  # button's mark, a way to add a button, and a photograph's tools, at
  # every level of the content, but those hidden under its values.
  defp drawn_controls(specs, content, prefix) do
    Enum.flat_map(specs, fn {field, spec} ->
      value = content && Map.get(content, field)
      path = prefix <> to_string(field)
      part = list_part(spec[:part])

      cond do
        hidden?(spec, content) ->
          []

        spec[:as] == :photo ->
          [{:photo_tools, path, "#section-photo-replace"}]

        spec[:as] == :part and part in [:action, :link] ->
          action_controls(path, value, spec[:optional])

        spec[:as] == :part and not is_nil(value) ->
          drawn_controls(Parts.editor_fields(spec[:part]), value, path <> ".")

        spec[:as] == :list and part in [:action, :link] ->
          actions_controls(path, value || [], Keyword.get(spec, :max, 12))

        spec[:as] == :list and is_list(value) ->
          value
          |> Enum.with_index()
          |> Enum.flat_map(fn {item, i} ->
            [
              {:item_tools, "#{path}.#{i}", ~s([id="section-item-#{path}-#{i}"])}
              | drawn_controls(Parts.editor_fields(spec[:part]), item, "#{path}.#{i}.")
            ]
          end)

        true ->
          []
      end
    end)
  end

  # A button the section has is marked, and one it can do without is
  # offered while it's absent.
  defp action_controls(path, nil, true),
    do: [{:add_button, path, "#section-add-button-#{Words.dashed(path)}"}]

  defp action_controls(_path, nil, _optional), do: []

  defp action_controls(path, _action, _optional),
    do: [{:editable_action, path, "#section-at-#{Words.dashed(path)}"}]

  # Each of a list's buttons is marked, and another is offered while it
  # has fewer than its most.
  defp actions_controls(path, actions, max) do
    marks =
      for {_action, i} <- Enum.with_index(actions),
          do: {:editable_action, "#{path}.#{i}", "#section-at-#{Words.dashed("#{path}.#{i}")}"}

    if length(actions) < max,
      do: marks ++ [{:add_button, path, "#section-add-button-#{Words.dashed(path)}"}],
      else: marks
  end

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

  # The selector of what the section editor draws for an entry, as
  # `Billboard.EditorLive.SectionEditor` and `EditorFields.setting/1`
  # draw it, or nil for one with no control of its own there: words typed
  # in place, checked as words, a required part, whose words are, and a
  # button, which the open section draws (`drawn_controls/3`).
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
      list_part(spec[:part]) in [:action, :link] -> nil
      count >= Keyword.get(spec, :max, 12) -> nil
      true -> "#section-add-#{field}"
    end
  end

  # A part the section can do without is added from the header, and taken
  # away under More, but a button, which the open section adds and opens.
  defp part_control(field, spec, content) do
    cond do
      !spec[:optional] -> nil
      list_part(spec[:part]) in [:action, :link] -> nil
      is_nil(Map.get(content, field)) -> "#section-add-#{field}"
      true -> "#section-drop-#{field}"
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
        if Keyword.has_key?(opts, :attrs) do
          flunk(
            "the `attrs:` given for #{inspect(component)} don't build: #{messages(error)}. " <>
              "Change them so they pass the component's validations."
          )
        else
          flunk(
            "#{inspect(component)}'s placeholder doesn't build: #{messages(error)}. " <>
              "Change `placeholder` in its `component` section so it passes the component's " <>
              "validations, or give `assert_component_works/2` the `attrs:` to build."
          )
        end
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

  # What the page hands its sections to draw them by, as
  # `Billboard.Sections.page/1` builds it: with a `library`, its sections,
  # by key, for a Shared section to draw the one it places.
  defp draw_ctx(data, context, library) do
    ctx = %{data: data, context: context, state: %{}}

    if library,
      do: Map.put(ctx, :shared, Map.new(library.sections, &{&1.key, &1})),
      else: ctx
  end

  # The id the section is drawn under: the hero's, its page's hero block;
  # a Shared section's, the library section it places, under that
  # section's own id, or none when it places none; any other's, its own.
  defp drawn_id(_section, :hero, _ctx), do: "page-hero"

  defp drawn_id(%{content: %{type: :shared, value: %{key: key}}}, :shared, ctx) do
    case Billboard.Sections.Shared.source(ctx, key) do
      nil -> nil
      library_section -> Billboard.Section.dom_id(library_section)
    end
  end

  defp drawn_id(section, _key, _ctx), do: Billboard.Section.dom_id(section)

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
