defmodule Billboard.ThemeCheckTest do
  @moduledoc """
  Stock sections draw only through billboard's theme, so they look
  right on any site: its colours, type, corners, and measures, and no
  colour, face, or corner a site might have of its own. The check is a
  guard, not an allowlist: it refuses what a site's palette looks like
  without knowing any site's names.
  """
  use ExUnit.Case, async: true

  alias Billboard.Test.ClassWords

  @theme Path.expand("../../assets/css/theme.css", __DIR__)

  describe "theme.css" do
    test "reads only --bb-* tokens" do
      assert foreign_vars(@theme, ~r/^bb-/) == []
    end

    test "names no colour of its own" do
      assert Regex.scan(~r/#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?|oklch)\(/, File.read!(@theme)) ==
               []
    end
  end

  # The stock files, under lib/billboard/sections: the stock renderers,
  # and the parts, blocks, words, buttons, glyphs, noise, and icons
  # they're drawn from, and the page, `lib/billboard/sections.ex`, which
  # sits beside that directory, not in it (`../sections.ex`), since it's
  # `Billboard.Sections` itself. The check reads their prose too, so
  # their comments and docs name the role, not a site's class.
  @web Path.expand("../../lib/billboard/sections", __DIR__)
  @stock ~w(buttons.ex voronoi.ex glyph.ex icons.ex blocks.ex words.ex parts.ex
            hero.ex band.ex points.ex text_media.ex details.ex reviews.ex news.ex
            columns.ex shared.ex ../sections.ex)

  # Tailwind's own type utilities, which set a size, weight, case,
  # tracking, leading, or style the theme's type roles should set.
  @type_utilities ~w(uppercase lowercase capitalize normal-case italic not-italic
                     font-thin font-extralight font-light font-normal font-medium font-semibold
                     font-bold font-extrabold font-black
                     text-xs text-sm text-base text-lg text-xl text-2xl text-3xl text-4xl
                     text-5xl text-6xl text-7xl text-8xl text-9xl)

  test "refuses what a site's classes look like, and passes the theme's" do
    site =
      ~s(text-white bg-slate-100 border-t-brand md:hover:text-primary/60 ring-offset-base
         divide-y-rule rounded-lg font-display font-sans type-h1 measure-body
         surface-dark hairline-rule text-sm leading-tight --site-ink from-white via-black
         to-slate-900 shadow-white/10 drop-shadow-white text-shadow-black/50 caret-white
         inset-ring-white placeholder-white)

    assert site
           |> ClassWords.words()
           |> Enum.reject(&(&1 == ""))
           |> Enum.reject(&stock_offence?/1) ==
             []

    # An arbitrary colour reads as its hex.
    assert Enum.any?(ClassWords.words("fill-[#fff]"), &stock_offence?/1)

    # Or by what it is inside its brackets.
    for class <- ~w|bg-[rgb(0_0_0)] text-[hsl(0_0%_100%)] fill-[oklch(0.5_0.1_20)]
                    bg-[color-mix(in_oklab,var(--bb-ink)_50%,transparent)]
                    text-[color:var(--bb-ink)] border-t-[white] md:hover:bg-[Crimson]| do
      assert arbitrary_colours(class) != [], class
    end

    # And an arbitrary property by its value, with or without a variant.
    for class <- ~w|[color:white] [background-color:Crimson] [fill:rgb(0_0_0)]
                    [--glow:oklch(0.5_0.1_20)] [border:1px_solid_red] md:hover:[color:navy]| do
      assert arbitrary_colours(class) != [], class
    end

    theme =
      ~s|text-bb-ink bg-transparent border-t-2 border-t border-dashed text-[13px] text-center
         outline-offset-2 decoration-1 stroke-none fill-current rounded-bb-card rounded-none
         font-bb-glyph bb-type-body bb-measure stroke-width="1.5" --bb-ink shadow-sm
         drop-shadow-none inset-shadow-xs text-shadow-lg from-10% via-50% to-90%
         caret-bb-ink ring-2 inset-ring-1 border-[length:var(--bb-button-border,1px)]
         transition-[color,text-decoration-color] aspect-[4/3] text-[20px]
         [color:var(--bb-ink)] [text-wrap:balance] [mask-type:luminance] [--bb-gap:2px]|

    assert theme |> ClassWords.words() |> Enum.filter(&stock_offence?/1) == []
    assert arbitrary_colours(theme) == []
  end

  for file <- @stock do
    test "#{file} draws only through the theme" do
      path = Path.join(@web, unquote(file))

      assert offences(path, offence(unquote(file))) == []
      assert path |> File.read!() |> arbitrary_colours() == []
    end
  end

  # Everything the editor draws: its controls, its section editor, and
  # the rest under `editor/` and `editor_live/`, and `editor.ex` and
  # `editor_live.ex` beside them, found by glob so a new file joins the
  # check, and the fields it draws that it doesn't type into on the page.
  # It reads neither a site's classes nor billboard's theme, only its own
  # tokens: its colours are `bb-edit-*` and `bb-glyph-*`, its type
  # `bb-edit-type-*`, its faces `font-bb-edit` and `font-bb-glyph`, and
  # its easing `ease-bb-edit`. The one colour of its own it names is its
  # popovers' neutral shadow, `shadow-[0_8px_24px_rgb(0_0_0/0.18)]`,
  # which is no theme's, so the check lets it be.
  @root Path.expand("../..", __DIR__)

  @editor_files Enum.sort(
                  Path.wildcard(Path.join(@root, "lib/billboard/editor/**/*.ex")) ++
                    Path.wildcard(Path.join(@root, "lib/billboard/editor_live/**/*.ex")) ++
                    Path.wildcard(Path.join(@root, "lib/billboard/{editor,editor_live}.ex")) ++
                    [Path.join(@root, "lib/billboard/sections/editor_fields.ex")]
                )

  test "the editor's files are found" do
    files = Enum.map(@editor_files, &Path.relative_to(&1, @root))

    for file <- ~w(lib/billboard/editor/components.ex lib/billboard/editor_live/section_editor.ex
                   lib/billboard/editor_live/palette.ex lib/billboard/sections/editor_fields.ex) do
      assert file in files
    end
  end

  test "the editor's check refuses the theme's corners, on every side or one" do
    for class <- ~w(rounded-bb-card rounded-t-bb-card rounded-tl-bb-field rounded-s-bb-button) do
      assert editor_offence?(class), class
    end

    for class <- ~w(rounded-full rounded-[6px] rounded-t-md) do
      refute editor_offence?(class), class
    end
  end

  for path <- @editor_files do
    test "#{Path.relative_to(path, @root)} draws only through the editor's tokens" do
      assert offences(unquote(path), &editor_offence?/1) == []
    end
  end

  # The editor's corners are its own, fixed ones, so it may round them as
  # it likes, but not with the theme's corners, which read the site's, on
  # every side or one (`rounded-t-bb-card`). It sets its own type, so
  # Tailwind's weights are its to use. Its motion is its own too, so it
  # takes neither the theme's easing nor its type roles, and an arbitrary
  # value may read only the editor's tokens. The one exception is
  # `bb-wrap`, which reads the page's content width and gutter, so the
  # page's issue strip lines up with the page, as the gutter exception in
  # the editor's stylesheet does. The old, unprefixed names of the theme
  # and of the editor's own utilities are out too, so they can't come
  # back.
  defp editor_offence?(class) do
    (site_class?(class) and not String.starts_with?(class, "rounded")) or
      ClassWords.colour?(class, ClassWords.theme_colours()) or
      String.starts_with?(class, "bb-type-") or Regex.match?(~r/^rounded(-[a-z]+)?-bb-/, class) or
      (class in ClassWords.theme_utilities() and class != "bb-wrap") or
      ClassWords.old_theme_name?(class) or ClassWords.old_editor_name?(class) or
      (Regex.match?(~r/^--[a-z]/, class) and not String.starts_with?(class, "--bb-edit-"))
  end

  # Glyphs are the palette's thumbnails, editor chrome rather than the
  # site, and drawn at a fixed size, so their quote mark sets its own
  # with `text-[20px] leading-none`. They're exempt from the type check
  # by file, not by naming `leading-none`, since glyph.ex holds nothing
  # but glyphs, and an allowed name would let every stock renderer use
  # it. Each renderer's own `glyph/1` lays out glyph.ex's parts, and
  # keeps the full check. Icons' `hero-*` names need no exemption: none
  # is a colour, a corner, or a type.
  defp offence("glyph.ex"), do: &(stock_offence?(&1) and not type_utility?(&1))
  defp offence(_file), do: &stock_offence?/1

  defp offences(path, offence?) do
    path
    |> ClassWords.read()
    |> Enum.filter(offence?)
    |> Enum.uniq()
  end

  # A stock file names neither a site's classes, nor a custom property
  # but billboard's (the splitter pulls them out of arbitrary values such
  # as `duration-[var(--bb-duration)]`), nor a colour of its own, nor
  # Tailwind's own type, nor the old, unprefixed names of the theme and
  # the editor's utilities with a hyphen, so they can't come back (the
  # names test covers the plain words, such as `card`).
  defp stock_offence?(class) do
    site_class?(class) or ClassWords.old_theme_name?(class) or
      ClassWords.old_editor_name?(class) or
      (Regex.match?(~r/^--[a-z]/, class) and not String.starts_with?(class, "--bb-")) or
      Regex.match?(~r/^#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/, class) or
      type_utility?(class)
  end

  defp type_utility?(class) do
    class in @type_utilities or String.starts_with?(class, ["tracking-", "leading-"])
  end

  # What a site's own classes look like: a colour that isn't the theme's,
  # a typeface that isn't billboard's, a corner but the theme's four, and
  # a type role, measure, surface, or hairline without the bb- prefix.
  defp site_class?(class) do
    foreign_colour?(class) or foreign_face?(class) or
      (String.starts_with?(class, "rounded") and
         class not in ~w(rounded-bb-card rounded-bb-button rounded-bb-photo rounded-bb-field
                         rounded-none)) or
      String.starts_with?(class, ~w(type- measure- surface- hairline-))
  end

  # A colour utility, as in `text-white`, `bg-slate-100`, or
  # `border-t-brand`, whose colour isn't billboard's (`bb-…`),
  # `transparent`, `current`, or `inherit`. What follows the utility, and
  # a side (`border-t`, `divide-x`) or `ring-offset`, is a colour unless
  # it's one of the utility's other values: a size (`text-[13px]` reads
  # as `text-` here, so it never matches), a width (`border-2`), a side,
  # or a keyword (`text-center`, `border-dashed`, `outline-offset-2`).
  # A word that ends in `=` is an attribute, as in an SVG's
  # `stroke-width="1.5"`, not a class.
  # The longer utilities come first, so `text-shadow-white` reads as a
  # shadow's colour, not as `text-` and `shadow-white`.
  # `from`, `via`, and `to` can match prose as well, as in "to-do" or
  # "from-scratch", which reads as a gradient stop's colour. That fails
  # safe: the check flags the word, and the prose is reworded.
  defp foreign_colour?(class) do
    case Regex.run(
           ~r/^(text-shadow|inset-shadow|drop-shadow|inset-ring|shadow|text|bg|border|outline|ring|decoration|accent|divide|fill|stroke|caret|placeholder|from|via|to)-(.+)$/,
           class
         ) do
      [_, utility, value] ->
        value = without_side(utility, value)

        value != "" and not String.ends_with?(value, "=") and
          not Regex.match?(~r/^\d+(\.\d+)?(px)?$/, value) and
          not Regex.match?(not_colours(utility), value) and
          not String.starts_with?(value, "bb-") and
          value not in ~w(transparent current inherit)

      nil ->
        false
    end
  end

  # Each colour utility's values that aren't colours. `text-decoration-*`
  # is a CSS property, as in `transition-[color,text-decoration-color]`.
  defp not_colours("text"),
    do:
      ~r/^(\d?xl|xs|sm|base|lg|left|center|right|justify|start|end|wrap|nowrap|balance|pretty|ellipsis|clip|decoration-.+)$/

  defp not_colours("bg"),
    do:
      ~r/^(cover|contain|auto|center|top|bottom|left|right|(left|right)-(top|bottom)|repeat(-.+)?|no-repeat|fixed|local|scroll|none|(clip|origin|blend|linear|radial|conic|gradient|size|position)(-.+)?)$/

  defp not_colours("border"),
    do: ~r/^(solid|dashed|dotted|double|hidden|none|collapse|separate|spacing(-.+)?)$/

  defp not_colours("outline"), do: ~r/^(none|hidden|solid|dashed|dotted|double|offset(-.+)?)$/
  defp not_colours("ring"), do: ~r/^inset$/

  defp not_colours("decoration"),
    do: ~r/^(solid|double|dotted|dashed|wavy|auto|from-font|clone|slice)$/

  defp not_colours("accent"), do: ~r/^auto$/
  defp not_colours("divide"), do: ~r/^(solid|dashed|dotted|double|none|(x|y)-reverse)$/
  defp not_colours(fill_or_stroke) when fill_or_stroke in ~w(fill stroke), do: ~r/^none$/
  defp not_colours("caret"), do: ~r/^auto$/

  defp not_colours(shadow) when shadow in ~w(shadow inset-shadow drop-shadow text-shadow),
    do: ~r/^(2xs|xs|sm|md|lg|xl|2xl|none|inner)$/

  # A gradient stop's position, as in `from-10%`.
  defp not_colours(stop) when stop in ~w(from via to), do: ~r/^\d+%$/

  # Every other value of an inset ring or a placeholder is a colour.
  defp not_colours(_utility), do: ~r/^$/

  # `border-t-2` is a width on a side, and `border-t-bb-rule` a colour on
  # one, so the side comes off before the value is read.
  defp without_side("border", value), do: String.replace(value, ~r/^[tblrxyse](-|$)/, "")
  defp without_side("divide", value), do: String.replace(value, ~r/^[xy](-|$)/, "")
  defp without_side("ring", value), do: String.replace(value, ~r/^offset(-|$)/, "")
  defp without_side(_utility, value), do: value

  # A typeface that isn't one of billboard's (`font-bb-…`): Tailwind's
  # `font-sans`, or a site's own `font-display`. A weight is a type
  # utility, which `type_utility?/1` reads.
  defp foreign_face?(class) do
    String.starts_with?(class, "font-") and not String.starts_with?(class, "font-bb-") and
      class not in @type_utilities
  end

  # The utilities that take a colour, with a side where one may have one.
  @colour_utility ~r/^(text-shadow|inset-shadow|drop-shadow|inset-ring|shadow|text|bg|border(-[tblrxyse])?|outline|ring(-offset)?|decoration|accent|divide(-[xy])?|fill|stroke|caret|placeholder|from|via|to)$/

  # CSS's named colours, which an arbitrary value may hold, as in
  # `bg-[white]`.
  @named_colours ~w(aliceblue antiquewhite aqua aquamarine azure beige bisque black
                    blanchedalmond blue blueviolet brown burlywood cadetblue chartreuse
                    chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan
                    darkgoldenrod darkgray darkgreen darkgrey darkkhaki darkmagenta
                    darkolivegreen darkorange darkorchid darkred darksalmon darkseagreen
                    darkslateblue darkslategray darkslategrey darkturquoise darkviolet deeppink
                    deepskyblue dimgray dimgrey dodgerblue firebrick floralwhite forestgreen
                    fuchsia gainsboro ghostwhite gold goldenrod gray green greenyellow grey
                    honeydew hotpink indianred indigo ivory khaki lavender lavenderblush
                    lawngreen lemonchiffon lightblue lightcoral lightcyan lightgoldenrodyellow
                    lightgray lightgreen lightgrey lightpink lightsalmon lightseagreen
                    lightskyblue lightslategray lightslategrey lightsteelblue lightyellow lime
                    limegreen linen magenta maroon mediumaquamarine mediumblue mediumorchid
                    mediumpurple mediumseagreen mediumslateblue mediumspringgreen
                    mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin
                    navajowhite navy oldlace olive olivedrab orange orangered orchid
                    palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff
                    peru pink plum powderblue purple rebeccapurple red rosybrown royalblue
                    saddlebrown salmon sandybrown seagreen seashell sienna silver skyblue
                    slateblue slategray slategrey snow springgreen steelblue tan teal thistle
                    tomato turquoise violet wheat white whitesmoke yellow yellowgreen)

  # The arbitrary values in `text` that hold a colour of their own: a
  # colour function (`rgb(…)`, `oklch(…)`, `color-mix(…)`), a `color:`
  # type hint, or, after a colour utility, a named colour. The splitter
  # breaks a value at its brackets and parentheses, so these are read
  # from the text whole. A hex is the splitter's (`stock_offence?/1`).
  defp arbitrary_colours(text), do: arbitrary_values(text) ++ arbitrary_properties(text)

  defp arbitrary_values(text) do
    for [class, utility, value] <- Regex.scan(~r/([a-z][a-z-]*)-\[([^\]\s"'`]+)\]/, text),
        colour_function?(value) or String.starts_with?(value, "color:") or
          (Regex.match?(@colour_utility, utility) and String.downcase(value) in @named_colours),
        do: class
  end

  # An arbitrary property, as in `[color:white]` or `hover:[fill:rgb(0_0_0)]`,
  # holds a colour of its own when its value has a colour function or, as
  # one of its words (`[border:1px_solid_red]`), a named colour, whatever
  # the property. It starts a word, or follows a variant's colon, so a
  # utility's arbitrary value (`text-[color:…]`) isn't read twice.
  defp arbitrary_properties(text) do
    for [class, _property, value] <-
          Regex.scan(~r/(?:^|[\s"'{:])(\[([a-z-]+):([^\]]+)\])/, text, capture: :all_but_first),
        colour_function?(value) or
          Enum.any?(String.split(value, "_"), &(String.downcase(&1) in @named_colours)),
        do: class
  end

  defp colour_function?(value),
    do: Regex.match?(~r/(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch|color-mix|color)\(/i, value)

  defp foreign_vars(path, allowed) do
    ~r/var\(\s*--([\w-]+)/
    |> Regex.scan(File.read!(path), capture: :all_but_first)
    |> List.flatten()
    |> Enum.reject(&Regex.match?(allowed, &1))
    |> Enum.uniq()
  end
end
