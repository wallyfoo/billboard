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
  # they're drawn from. The check reads their prose too, so their
  # comments and docs name the role, not a site's class.
  @web Path.expand("../../lib/billboard/sections", __DIR__)
  @stock ~w(buttons.ex voronoi.ex glyph.ex icons.ex)

  # Tailwind's own type utilities, which set a size, weight, case,
  # tracking, leading, or style the theme's type roles should set.
  @type_utilities ~w(uppercase lowercase capitalize normal-case italic not-italic
                     font-thin font-extralight font-light font-normal font-medium font-semibold
                     font-bold font-extrabold font-black
                     text-xs text-sm text-base text-lg text-xl text-2xl text-3xl text-4xl
                     text-5xl text-6xl text-7xl text-8xl text-9xl)

  test "refuses what a site's classes look like, and passes the theme's" do
    site =
      ~s(text-white bg-slate-100 border-t-mulberry md:hover:text-aubergine/60 ring-offset-paper
         divide-y-rule rounded-lg font-display font-sans type-h1 measure-body
         surface-dark hairline-rule text-sm leading-tight --site-ink)

    assert site
           |> ClassWords.words()
           |> Enum.reject(&(&1 == ""))
           |> Enum.reject(&stock_offence?/1) ==
             []

    # An arbitrary colour reads as its hex.
    assert Enum.any?(ClassWords.words("fill-[#fff]"), &stock_offence?/1)

    theme =
      ~s(text-bb-ink bg-transparent border-t-2 border-t border-dashed text-[13px] text-center
         outline-offset-2 decoration-1 stroke-none fill-current rounded-bb-card rounded-none
         font-bb-glyph bb-type-body bb-measure stroke-width="1.5" --bb-ink)

    assert theme |> ClassWords.words() |> Enum.filter(&stock_offence?/1) == []
  end

  for file <- @stock do
    test "#{file} draws only through the theme" do
      assert offences(Path.join(@web, unquote(file)), offence(unquote(file))) == []
    end
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
  # `border-t-mulberry`, whose colour isn't billboard's (`bb-…`),
  # `transparent`, `current`, or `inherit`. What follows the utility, and
  # a side (`border-t`, `divide-x`) or `ring-offset`, is a colour unless
  # it's one of the utility's other values: a size (`text-[13px]` reads
  # as `text-` here, so it never matches), a width (`border-2`), a side,
  # or a keyword (`text-center`, `border-dashed`, `outline-offset-2`).
  # A word that ends in `=` is an attribute, as in an SVG's
  # `stroke-width="1.5"`, not a class.
  defp foreign_colour?(class) do
    case Regex.run(
           ~r/^(text|bg|border|outline|ring|decoration|accent|divide|fill|stroke)-(.+)$/,
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
      ~r/^(\d?xl|xs|sm|base|lg|left|center|right|justify|start|end|wrap|nowrap|balance|pretty|ellipsis|clip|shadow(-.+)?|decoration-.+)$/

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

  defp foreign_vars(path, allowed) do
    ~r/var\(\s*--([\w-]+)/
    |> Regex.scan(File.read!(path), capture: :all_but_first)
    |> List.flatten()
    |> Enum.reject(&Regex.match?(allowed, &1))
    |> Enum.uniq()
  end
end
