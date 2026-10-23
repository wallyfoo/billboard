defmodule Billboard.ThemeNamesTest do
  @moduledoc """
  Every utility billboard ships carries a bb- prefix, so it can't clash
  with a name a site already has, such as daisyUI's `card` and `accent`
  on a fresh `mix phx.new` site, or a site's own `rule`. Nothing in the
  library's lib/, assets/js/, or assets/css/ may use the old, unprefixed
  names of the theme or the editor.
  """
  use ExUnit.Case, async: true

  alias Billboard.Test.ClassWords

  @root Path.expand("../..", __DIR__)
  @files Path.wildcard(Path.join(@root, "lib/**/*.{ex,heex,js}")) ++
           Path.wildcard(Path.join(@root, "assets/js/**/*.js")) ++
           Path.wildcard(Path.join(@root, "assets/css/**/*.css"))

  test "it reads the stock sections and the CSS" do
    files = Enum.map(@files, &Path.relative_to(&1, @root))

    for file <- ~w(lib/billboard/sections/buttons.ex
                   lib/billboard/sections/blocks.ex
                   lib/billboard/sections/words.ex
                   lib/billboard/sections/parts.ex
                   lib/billboard/sections/editor_fields.ex
                   lib/billboard/sections/hero.ex
                   lib/billboard/sections/band.ex
                   lib/billboard/sections/points.ex
                   lib/billboard/sections/text_media.ex
                   lib/billboard/sections/details.ex
                   lib/billboard/sections/reviews.ex
                   lib/billboard/sections/news.ex
                   assets/css/theme.css) do
      assert file in files
    end
  end

  test "it matches whole class words only" do
    assert theme_names(~s(class="md:hover:text-ink/40 type-body section-pad")) ==
             ~w(text-ink type-body section-pad)

    assert theme_names(~s(class="flex-wrap text-ink-soft-ish measure-body type-h1")) == []
    assert theme_names(~s(class="text-bb-ink bb-type-body bb-wrap rounded-bb-card bb-card")) == []

    assert theme_names(~s(class="[&_.type-body]:mt-2" "p.border-rule")) ==
             ~w(type-body border-rule)

    assert theme_names("bg-[var(--color-ink)] rounded-[var(--radius-card)]") ==
             ~w(--color-ink --radius-card)
  end

  test "it reads the plain words among the old names only where a class can be" do
    assert theme_names(~s(<div class="wrap grid">)) == ~w(wrap)
    assert theme_names(~s(class={["bb-wrap", "card"]})) == ~w(card)
    assert theme_names(~s|has?(doc, "#c.wrap")|) == ~w(wrap)

    assert theme_names(~s(<script :type={Hook}>el.className = `measure ${x}`</script>)) ==
             ~w(measure)

    assert theme_names(~s|el.classList.add("wrap")|, :js) == ~w(wrap)
    assert theme_names("el.classList.add('card')", :js) == ~w(card)
    assert theme_names("el.className = `wrap ${size}`", :js) == ~w(wrap)

    assert theme_names(
             "Surfaces.offered(:card) [:page, :stand_out, :card] def card(assigns), do: x " <>
               "List.wrap(x) &List.wrap/1 # a card's edge isn't the card's ground"
           ) == []

    assert theme_names("function hug(inner, wrap) { return wrap(core) }", :js) == []

    assert theme_names(~s|@doc "Never `:card`, the kind of a card"|) == []
    assert theme_names(~s|raise "a card inside a section, not of one"|) == []
    assert theme_names(~s|el.classList.add("card")|, :js) == ~w(card)
  end

  test "it reads CSS by its utilities and selectors" do
    assert theme_names("@utility wrap { width: 100%; }", :css) == ~w(wrap)
    assert theme_names(".card, .md\\:measure { color: red }", :css) == ~w(card measure)

    assert theme_names("--color-rule: var(--bb-rule); --radius-card: 0;", :css) ==
             ~w(--color-rule --radius-card)

    assert theme_names(".hover\\:text-ink:hover { }", :css) == ~w(text-ink)

    assert theme_names(
             "flex-wrap: wrap; @utility bb-wrap { } .bb-card { } /* a card's fill */",
             :css
           ) == []
  end

  test "it matches the editor's old utilities and hooks, not ids or data attributes" do
    assert editor_names(
             ~s(class="text-edit-ink bg-edit hover:bg-glyph-ink/30 font-edit ease-edit")
           ) ==
             ~w(text-edit-ink bg-edit bg-glyph-ink font-edit ease-edit)

    assert editor_names(
             ~s(class="[&>option]:text-edit-ink edit-type-small md:edit-type-body" ".bg-edit-warn")
           ) == ~w(text-edit-ink edit-type-small edit-type-body bg-edit-warn)

    assert editor_names("--color-edit-ink: x; --font-glyph: y;", :css) ==
             ~w(--color-edit-ink --font-glyph)

    assert editor_names("edit-section edit-gap-add inline-words words-count") ==
             ~w(edit-section edit-gap-add inline-words words-count)

    assert editor_names(
             "bb-edit-section bb-edit-gap bb-inline-words data-edit-section #mode-edit " <>
               "#edit-canvas text-bb-edit-ink bg-bb-edit font-bb-edit ease-bb-edit " <>
               "bb-edit-type-small"
           ) == []
  end

  test "nothing uses the theme's old names" do
    assert offences(&theme_names/2) == []
  end

  test "nothing uses the editor's old names" do
    assert offences(&editor_names/2) == []
  end

  defp offences(names) do
    for path <- @files,
        found = path |> File.read!() |> names.(kind(path)) |> Enum.uniq(),
        found != [],
        do: {Path.relative_to(path, @root), found}
  end

  defp kind(path) do
    case Path.extname(path) do
      ".css" -> :css
      ".js" -> :js
      _ -> :elixir
    end
  end

  defp theme_names(text, kind \\ :elixir),
    do: old_names(text, kind, &ClassWords.old_theme_name?/1, &ClassWords.bare_old_name?/1)

  defp editor_names(text, kind \\ :elixir),
    do: old_names(text, kind, &ClassWords.old_editor_name?/1, fn _ -> false end)

  # The old names with a hyphen can't be Elixir or JS names, so they count
  # anywhere in a file. The plain words (`wrap`, `measure`, and `card`)
  # count only where a class can be: in a string in Elixir, HEEx, and JS,
  # and as a utility or a selector in CSS.
  defp old_names(text, kind, old?, bare?) do
    hyphenated = text |> words(kind) |> with_selector_parts() |> Enum.filter(old?)
    bare = text |> class_places(kind) |> Enum.filter(bare?)
    hyphenated ++ bare
  end

  # CSS has no variants to strip from its words, but its declarations end
  # in colons and semicolons, and its escaped selectors hide a variant
  # behind a backslash, as in `.md\:bb-wrap`.
  defp words(text, :css), do: String.split(text, ~r/[\s"'`{}\[\](),;:\\]+/)
  defp words(text, _kind), do: ClassWords.words(text)

  defp class_places(text, :css) do
    utilities = Regex.scan(~r/@utility\s+([\w-]+)/, text, capture: :all_but_first)

    selectors =
      ~r/(?<![\w-])\.((?:\\.|[\w-])+)/
      |> Regex.scan(text, capture: :all_but_first)
      |> Enum.map(fn [selector] ->
        [selector |> String.replace(~r/\\(.)/, "\\1") |> String.split(":") |> List.last()]
      end)

    List.flatten(utilities ++ selectors)
  end

  defp class_places(text, kind) do
    text
    |> literals(kind)
    |> Enum.flat_map(&ClassWords.words/1)
    |> with_selector_parts()
  end

  # Strings on one line, in double or single quotes. A single quote counts
  # only with no letter before it, so the apostrophe in "the card's edge"
  # opens nothing. A string that reads as prose, a doc or a message, holds
  # no class: it has a backtick, or a comma or full stop and a space,
  # which no class list has, so the library can say "a card inside a
  # section". JS template literals, in backticks, can span lines: in a JS
  # file, and in the scripts of an Elixir file's colocated hooks.
  defp literals(text, kind) do
    quoted =
      ~r/"(?:[^"\\\n]|\\.)*"|(?<!\w)'(?:[^'\\\n]|\\.)*'(?!\w)/
      |> Regex.scan(text)
      |> List.flatten()
      |> Enum.reject(&(&1 =~ ~r/`|[,.] /))

    scripts =
      case kind do
        :js -> [text]
        _ -> ~r/<script\b[^>]*>(.*?)<\/script>/s |> Regex.scan(text, capture: :all_but_first)
      end

    templates =
      scripts
      |> List.flatten()
      |> Enum.flat_map(&(~r/`(?:[^`\\]|\\.)*`/s |> Regex.scan(&1) |> List.flatten()))

    quoted ++ templates
  end

  # A word's parts after a dot count too, as in a selector such as
  # `[&_.type-body]:mt-2`, but not in a word that calls a module, such as
  # `&List.wrap`.
  defp with_selector_parts(words), do: Enum.flat_map(words, &[&1 | selector_parts(&1)])

  defp selector_parts(word) do
    if word =~ ~r/\b[A-Z]\w*\./, do: [], else: word |> String.split(~r/[.&_>+~]+/) |> tl()
  end
end
