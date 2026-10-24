defmodule Billboard.Test.ClassWords do
  @moduledoc """
  Reads a source file as the class words in it, for the theme check and
  the names test. A word is what's left between spaces, quotes (backticks
  included), braces, brackets, parentheses, and commas, with its Tailwind variants (`md:`,
  `hover:`, `in-[…]:`) and its opacity (`/40`) taken off, so
  `md:hover:text-bb-ink/40` reads as `text-bb-ink`. Custom properties
  inside arbitrary values come out as words of their own, such as
  `--bb-duration` from `duration-[var(--bb-duration)]`.

  It also knows the names billboard's theme and the editor's stylesheet
  used before every utility they ship took the `bb-` prefix, so that
  both tests can keep them from coming back.
  """

  # Tailwind's utilities that take a colour, as in `border-t-bb-rule`.
  @colour_prefixes ~w(text bg border border-t border-b border-l border-r border-x border-y
                      border-s border-e outline decoration fill stroke ring ring-offset
                      inset-ring shadow inset-shadow drop-shadow text-shadow divide accent
                      caret placeholder from via to)

  # The theme's colours by role, unprefixed, as they were named before
  # the rename: `ink` was `--color-ink` and `text-ink`, and is now
  # `--color-bb-ink` and `text-bb-ink`.
  @colour_roots ~w(ink ink-soft title heading subheading eyebrow link link-hover accent rule
                   edge card placeholder placeholder-ink placeholder-chip focus action
                   on-action action-hover on-action-hover action-active on-action-active
                   action-2 on-action-2)

  @old_theme_names Enum.map(@colour_roots, &"--color-#{&1}") ++
                     ~w(--radius-card --radius-button --radius-photo --radius-field
                        rounded-card rounded-button rounded-photo rounded-field
                        type-display type-title type-heading type-subheading type-quote
                        type-lead type-body type-small type-label type-eyebrow type-button
                        section-pad measure-title)

  # The old layout names that are plain words as well, so they can be
  # Elixir and JS names too, such as `:card`, `card/1`, or `List.wrap`.
  @bare_theme_names ~w(wrap measure card)

  # The editor's colours by role, unprefixed: its blue, its chrome, and
  # the palette's glyphs.
  @edit_colour_roots ~w(edit edit-on-accent edit-ink edit-soft edit-faint edit-line edit-ground
                        edit-ground-alt edit-paper edit-error edit-warn edit-warn-on-ink
                        edit-disabled glyph-ink glyph-soft glyph-faint glyph-paper glyph-accent
                        glyph-accent-on-ink glyph-line)

  @old_editor_names Enum.map(@edit_colour_roots, &"--color-#{&1}") ++
                      ~w(--font-edit --font-glyph --ease-edit font-edit font-glyph ease-edit
                         edit-type-body edit-type-small edit-type-label edit-type-button)

  # The editor's structural classes, the attributes its hooks set, and
  # its keyframe, as they were before they took the bb- prefix.
  @old_editor_hooks ~w(edit-section edit-stand-in edit-section-tag edit-section-issue edit-gap
                       edit-gap-add edit-action edit-add-inline edit-item edit-item-tools
                       edit-item-ground edit-shows-on edit-photo-tools inline-words editor-flash
                       edit-pop edit-probe edit-closing words-count words-over words-refused)

  @doc "The class words in the file at `path`."
  def read(path), do: path |> File.read!() |> words()

  @doc "The class words in `text`."
  def words(text) do
    text
    |> String.split(~r/[\s"'`{}\[\](),]+/)
    |> Enum.map(&(&1 |> String.split(":") |> List.last() |> String.replace(~r"/\d+$", "")))
  end

  # The theme's utilities that are neither a colour, a corner, nor a type
  # role: its easing and duration, and its layout classes.
  @theme_utilities ~w(ease-bb duration-bb bb-card bb-wrap bb-measure bb-measure-title
                      bb-section-pad bb-rule-top)

  @doc """
  The theme's utilities that are neither a colour (`theme_colours/0`), a
  corner (`rounded-bb-*`), nor a type role (`bb-type-*`): its easing,
  its duration, and its layout classes. Every check that keeps the
  theme out of the editor reads them here.
  """
  def theme_utilities, do: @theme_utilities

  @doc "The theme's colours, as `@theme` names them after `--color-`."
  def theme_colours, do: Enum.map(@colour_roots, &"bb-#{&1}")

  @doc "Whether `class` sets one of `colours`, as in `text-bb-ink` or `border-t-bb-rule`."
  def colour?(class, colours) do
    Enum.any?(@colour_prefixes, fn prefix ->
      Enum.any?(colours, &(class == "#{prefix}-#{&1}"))
    end)
  end

  @doc """
  Whether `class` is one of the theme's names from before the rename: a
  colour, a corner, a type role, or a layout utility, unprefixed. Each of
  these has a hyphen, so none can be an Elixir name. The plain words
  among the old names are `bare_old_name?/1`'s.
  """
  def old_theme_name?(class) do
    colour?(class, @colour_roots) or class in @old_theme_names
  end

  @doc """
  Whether `class` is one of the theme's old layout names that are plain
  words: `wrap`, `measure`, and `card`. Read them only where a class can
  be, such as in a string, since `:card` and `List.wrap` are fine.
  """
  def bare_old_name?(class), do: class in @bare_theme_names

  @doc """
  Whether `class` is one of the editor's names from before the rename: a
  colour, a typeface, its easing, or its type, unprefixed, or one of its
  structural classes, its hooks' attributes, or its keyframe, which took
  the bb- prefix too (`bb-edit-gap`, `bb-words-count`).
  """
  def old_editor_name?(class) do
    colour?(class, @edit_colour_roots) or class in @old_editor_names or
      class in @old_editor_hooks
  end
end
