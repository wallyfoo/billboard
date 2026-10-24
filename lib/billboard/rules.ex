defmodule Billboard.Rules do
  @moduledoc """
  The stock composition rules the builder enforces. `check/3` reads a
  page's sections and returns what is wrong with them: an `:error` blocks
  a commit, and a `:warning` only advises. Each issue names the section
  it is about by `key`, or `nil` when it is about the whole page.

  The rules read sections in memory and never touch the database, so the
  editor can check a draft as it changes. They take the top-level sections
  in order, each Two columns section with its `children` loaded, and
  `shared`, the shared library's sections by key, as
  `Billboard.Pages.shared_sections/0` gives them, so a shared section's
  anchor is known.

    * Every page but the library opens with exactly one hero, when the
      site has a `:hero` component; the library has none.
    * A fixed page has exactly its fixed sections, in order.
    * A component goes only on the kinds of page its catalogue entry lists,
      and a page holds no more of it than the entry's `max`.
    * Two columns hold exactly two sections, each one that fits in a
      column.
    * More than one primary action in a section is a warning.
    * A shared section goes on a page once, and no other section on the
      page may take its anchor, so no DOM id repeats.
    * A shared section whose source has left the library is a warning.

  A component adds rules about its own sections, each a
  `Billboard.Component.Rule`, through its `component` section's `rules`,
  and `check/3` runs them after the stock rules, on each of its sections,
  those in columns included. A site adds its own rules, each a
  `Billboard.Rule`, through its site module's `rules/0`, and `check/3`
  runs them last, so their issues come last. "Never the same ground twice
  in a row" would be one.
  `everything/1`, `type/1`, `effective_type/2`, and `actions_of/1` are
  public so a site's rules can read sections as these do.
  """
  alias Billboard.{Catalogue, Site}
  alias Billboard.Catalogue.Entry
  alias Billboard.Component.Info
  alias Billboard.Directory.Page

  import Billboard.Rule, only: [error: 2, warning: 2]

  @type issue :: Billboard.Rule.issue()
  @type shared :: %{optional(String.t()) => map()}

  @doc """
  Every issue with `sections` on `page`: errors and warnings, with the
  section each is about. The stock rules' issues come first, then the
  components' own rules', section by section in the page's order, then
  each of the site's rules' in the order `rules/0` lists them.
  """
  @spec check(Page.t(), [map()], shared()) :: [issue()]
  def check(%Page{} = page, sections, shared) do
    stock =
      Enum.concat([
        heroes(page, sections),
        fixed(page, sections),
        placement(page, sections),
        maxima(sections),
        columns(sections),
        actions(sections),
        anchors(sections, shared),
        shared_refs(sections, shared)
      ])

    components = component_issues(page, sections, shared)
    site = Enum.flat_map(Site.get!().rules(), & &1.check(page, sections, shared))

    stock ++ components ++ site
  end

  @doc "Only the issues that block a commit."
  @spec errors(Page.t(), [map()], shared()) :: [issue()]
  def errors(page, sections, shared) do
    page
    |> check(sections, shared)
    |> Enum.filter(&(&1.level == :error))
  end

  # Each component's own rules, on each of its sections, in the page's
  # order, columns' sections included.
  defp component_issues(page, sections, shared) do
    for s <- everything(sections),
        rule <- Info.component_rules!(Catalogue.module!(type(s))),
        issue <- rule.check(s, page, shared),
        do: issue
  end

  defp heroes(page, sections) do
    if :hero in Catalogue.keys(), do: hero_issues(page, sections), else: []
  end

  defp hero_issues(%Page{kind: :library}, sections) do
    for s <- sections, type(s) == :hero, do: error(s, "shared sections can't include a hero")
  end

  defp hero_issues(_page, sections) do
    opening =
      case sections do
        [first | _] ->
          if type(first) == :hero, do: [], else: [error(first, "the page opens with its hero")]

        [] ->
          [error(nil, "the page opens with its hero")]
      end

    extra =
      sections
      |> Enum.filter(&(type(&1) == :hero))
      |> Enum.drop(1)
      |> Enum.map(&error(&1, "a page has one hero"))

    opening ++ extra
  end

  defp fixed(%Page{fixed: nil}, _sections), do: []

  defp fixed(%Page{fixed: fixed}, sections) do
    if Enum.map(sections, &type/1) == fixed do
      []
    else
      labels = Enum.map_join(fixed, ", then ", &Catalogue.label/1)
      [error(nil, "this page's sections are fixed: #{labels}")]
    end
  end

  # A hero in the library is left to `heroes/2`, which says it better.
  defp placement(%Page{kind: kind}, sections) do
    for s <- everything(sections),
        not (kind == :library and type(s) == :hero),
        entry = Catalogue.fetch!(type(s)),
        not Entry.allows?(entry, kind),
        do: error(s, "#{entry.label} can't go on this page")
  end

  # The hero is left to `heroes/2`, which says it better.
  defp maxima(sections) do
    all = everything(sections)

    for %{key: key, max: max, label: label} <- Catalogue.entries(),
        key != :hero and is_integer(max),
        matching = Enum.filter(all, &(type(&1) == key)),
        length(matching) > max,
        do: error(Enum.at(matching, max), "a page has at most #{in_words(max)} #{label}")
  end

  defp columns(sections) do
    for s <- sections, type(s) == :columns, issue <- column_issues(s), do: issue
  end

  defp column_issues(section) do
    children = children(section)

    count =
      if length(children) == 2,
        do: [],
        else: [error(section, "two columns hold exactly two sections")]

    misfits =
      for child <- children,
          entry = Catalogue.fetch!(type(child)),
          not entry.column?,
          do: error(child, "#{entry.label} can't sit in a column")

    count ++ misfits
  end

  defp actions(sections) do
    for s <- everything(sections),
        n = Enum.count(actions_of(s), &(&1.style == :primary)),
        n > 1,
        do: warning(s, "use one primary action per section; #{Catalogue.label(type(s))} has #{n}")
  end

  # A shared section draws its library section with the library's anchor,
  # so placing it twice, or giving another section on the page the same
  # anchor, would repeat a DOM id.
  defp anchors(sections, shared) do
    {_keys, repeats} =
      Enum.reduce(placed(sections), {[], []}, fn s, {keys, repeats} ->
        key = s.content.value.key

        if key in keys,
          do: {keys, [error(s, "a shared section goes on a page once") | repeats]},
          else: {[key | keys], repeats}
      end)

    clashes =
      for {s, id} <- anchor_clashes(sections, shared),
          do: error(s, "the shared section on this page has this anchor too (#{id})")

    Enum.reverse(repeats) ++ clashes
  end

  @doc """
  The sections of a page (`sections`, as `check/3` takes them) whose DOM
  id is also the id of a shared section the page places, or of one of its
  children, each with that id. `shared` is the library's sections by key,
  so a library draft can be checked against the pages that place it
  before it is committed. The hero renders into the header, with no
  anchor of its own.
  """
  @spec anchor_clashes([map()], shared()) :: [{map(), String.t()}]
  def anchor_clashes(sections, shared) do
    taken =
      for place <- placed(sections),
          library = Map.get(shared, place.content.value.key),
          s <- [library | library_children(library)],
          into: MapSet.new(),
          do: Billboard.Section.dom_id(s)

    for s <- everything(sections),
        type(s) not in [:hero, :shared],
        id = Billboard.Section.dom_id(s),
        id in taken,
        do: {s, id}
  end

  defp placed(sections), do: for(s <- everything(sections), type(s) == :shared, do: s)

  defp library_children(%{children: children}) when is_list(children), do: children
  defp library_children(_section), do: []

  defp shared_refs(sections, shared) do
    for s <- everything(sections),
        type(s) == :shared,
        not Map.has_key?(shared, s.content.value.key),
        do: warning(s, "this shared section is no longer in the library")
  end

  @doc """
  Every action `section` shows: its own list (`actions`) or single
  action (`action`), and its head's action (`head.action`). A link inside
  any other part, such as a list item's, is left out, since a site draws
  it as a text link, and so is anything with no `style`, such as what a
  site's own head part holds as its `action`, which isn't a button.
  """
  @spec actions_of(map()) :: [map()]
  def actions_of(%{content: %Ash.Union{value: value}}) do
    head_action =
      case Map.get(value, :head) do
        %{action: action} -> [action]
        _no_action -> []
      end

    [Map.get(value, :actions) || [], [Map.get(value, :action)], head_action]
    |> Enum.concat()
    |> Enum.filter(&match?(%{style: _}, &1))
  end

  @doc """
  The top-level `sections`, each followed by its children. Raises for a
  Two columns section whose children aren't loaded, since the rules can't
  judge them.
  """
  @spec everything([map()]) :: [map()]
  def everything(sections), do: Enum.flat_map(sections, &[&1 | children(&1)])

  # Only Two columns sections hold children, and the rules can't judge
  # them unless they are loaded.
  defp children(%{content: %Ash.Union{type: :columns}, children: children})
       when is_list(children),
       do: children

  defp children(%{content: %Ash.Union{type: :columns}, key: key}) do
    raise ArgumentError,
          "load the children of Two columns section #{inspect(key)} before checking the rules"
  end

  defp children(_section), do: []

  @doc """
  The type of what `section` draws: a Shared section's library section's
  type, found in `shared`, or `:shared` when that has left the library,
  and any other section's own type.
  """
  @spec effective_type(map(), shared()) :: atom()
  def effective_type(%{content: %Ash.Union{type: :shared, value: %{key: key}}}, shared) do
    case Map.get(shared, key) do
      %{} = library -> type(library)
      nil -> :shared
    end
  end

  def effective_type(section, _shared), do: type(section)

  @doc "The type of `section`'s content."
  @spec type(map()) :: atom()
  def type(%{content: %Ash.Union{type: type}}), do: type

  defp in_words(1), do: "one"
  defp in_words(2), do: "two"
  defp in_words(n), do: Integer.to_string(n)
end
