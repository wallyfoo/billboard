defmodule Billboard.EditorLive.Palette do
  @moduledoc """
  Adding a section in the page editor: what a page may add (`options/3`),
  and the place to add it, between two of the page's sections (`gap/1`).

  Each place is known by where a new section would go among the page's
  top-level sections (`at`): after the hero, between any two sections,
  and after the last, but never before the hero, which stays first. The
  library, which has no hero, has a place before its first section too.
  `Billboard.Sections.page/1` draws them, from the editor's ctx
  (`ctx.edit.add`), in `<main>`; a fixed page has none.

  A place is a line with "+ Add a section" on it, shown when the pointer
  is near it and always on a touch screen. It opens the palette there: the
  components this page may add, by category, each with a small picture of
  its shape and what it's for, or why it can't be added now.
  """
  use Phoenix.Component

  alias Billboard.{Catalogue, Sections}
  alias Billboard.Catalogue.Entry
  alias Billboard.EditorLive.Messages
  alias Phoenix.LiveView.JS

  @doc """
  The palette for `page`, holding `sections`, with the shared `library`'s
  sections: its categories, each with the components the page may add, as
  `%{entry: entry, disabled: reason, glyph: section}`, where `reason` says
  why it can't be added now (nil when it can), and `glyph` is a section
  holding the component's placeholder, for `Sections.glyph/1` to draw. A
  fixed page has none. The hero isn't offered: every page has exactly one,
  and keeps it.

  `glyphs` are those sections, from `glyphs/0`, which the editor makes
  once.
  """
  @spec options(map(), [map()], [map()], map()) :: [{atom(), [map()]}]
  def options(page, sections, library, glyphs \\ glyphs()) do
    if is_list(page.fixed) do
      []
    else
      all = Enum.flat_map(sections, &[&1 | &1.children])

      for category <- Catalogue.categories(),
          options =
            for(
              entry <- Catalogue.entries(),
              entry.category == category,
              entry.key != :hero,
              Entry.allows?(entry, page.kind),
              not (page.kind == :library and entry.key == :shared),
              do: %{
                entry: entry,
                disabled: unavailable(entry, all, sections, library),
                glyph:
                  Map.get_lazy(glyphs, entry.key, fn -> glyph(entry.key, sections, library) end)
              }
            ),
          options != [],
          do: {category, options}
    end
  end

  @doc """
  The glyphs' sections of the components whose glyph is the same on every
  page: all but a Shared section's, which shows the library section it
  would place.
  """
  @spec glyphs() :: %{atom() => map()}
  def glyphs do
    for entry <- Catalogue.entries(), entry.key not in [:hero, :shared], into: %{} do
      {entry.key, glyph(entry.key, [], [])}
    end
  end

  @doc """
  The keys of the library's sections that none of `sections`, or their
  columns, place yet.
  """
  @spec unplaced([map()], [map()]) :: [String.t()]
  def unplaced(library, sections) do
    placed =
      for s <- Enum.flat_map(sections, &[&1 | &1.children]),
          s.content.type == :shared,
          do: s.content.value.key

    for s <- library, s.key not in placed, do: s.key
  end

  @doc """
  The places a new section can go among `sections`, the page's top-level
  sections: anywhere from after the hero, or the first, to after the last.
  """
  @spec places([map()]) :: Range.t()
  def places([%{content: %{type: :hero}} | _] = sections), do: 1..length(sections)
  def places(sections), do: 0..length(sections)

  # Shared and Two columns have reasons of their own, then a page's
  # limit (`max_reached/2`), as every other component has.
  defp unavailable(%{key: :shared} = entry, all, sections, library) do
    cond do
      library == [] -> "The shared library is empty."
      unplaced(library, sections) == [] -> Messages.message(:nothing_to_share)
      true -> max_reached(entry, all)
    end
  end

  # Two columns arrive holding two of a component that fits in a column
  # (`column_type/0`), so on a site with none they can't be added.
  defp unavailable(%{key: :columns} = entry, all, _sections, _library) do
    if column_type(),
      do: max_reached(entry, all),
      else: "Nothing on this site fits in a column."
  end

  defp unavailable(entry, all, _sections, _library), do: max_reached(entry, all)

  # Counts include the sections inside Two columns, as the rules' do.
  defp max_reached(%{key: key, max: max, label: label}, all) when is_integer(max) do
    if Enum.count(all, &(&1.content.type == key)) >= max,
      do: "#{label} is already on this page.",
      else: nil
  end

  defp max_reached(_entry, _all), do: nil

  # A section as the component arrives: its placeholder, and for Two
  # columns, two Details, or two of the first component that fits in a
  # column on a site without Details, or none on a site with neither. A
  # shared section shows the library section it would place, or, with
  # none left to place, the library's first.
  defp glyph(:shared, sections, library) do
    key = List.first(unplaced(library, sections) ++ Enum.map(library, & &1.key)) || "none"
    sample(:shared, Billboard.Component.build!(:shared, %{key: key}), [])
  end

  defp glyph(:columns, _sections, _library) do
    children =
      case column_type() do
        nil -> []
        type -> List.duplicate(sample(type, placeholder(type), []), 2)
      end

    sample(:columns, placeholder(:columns), children)
  end

  defp glyph(type, _sections, _library), do: sample(type, placeholder(type), [])

  @doc """
  The component Two columns arrive holding, and are drawn holding in the
  palette: Details, or, on a site without it, the first component that
  fits in a column (`column? true`), or nil.
  """
  @spec column_type() :: atom() | nil
  def column_type do
    entries = Catalogue.entries()

    if Enum.any?(entries, &(&1.key == :details)),
      do: :details,
      else: Enum.find_value(entries, &(&1.column? && &1.key))
  end

  defp placeholder(type), do: Billboard.Component.build!(type, Catalogue.placeholder(type))

  defp sample(type, value, children),
    do: %{
      key: "palette-#{type}",
      content: %Ash.Union{type: type, value: value},
      children: children
    }

  attr :at, :integer, required: true, doc: "where a section added here goes"

  attr :add, :map,
    required: true,
    doc: "the editor's `ctx.edit.add`: the palette, the library by key, and where it's open"

  @doc """
  A place to add a section, with the palette while it's open there. It is
  marked as the editor's own (`data-editor-ui`), so the canvas's hook lets
  its clicks through and doesn't take them for a click outside every
  section.

  A click outside an open palette closes it, saying where it was, so that
  a click on another place, which opens the palette there, can't be undone
  by the first one's closing arriving after it. An entry that can't be
  added now is marked so (`aria-disabled`), not disabled, so the keyboard
  still reaches it and its reason is read out; it sends nothing.
  """
  def gap(assigns) do
    assigns = assign(assigns, :open?, assigns.add.at == assigns.at)

    ~H"""
    <div
      id={"section-gap-#{@at}"}
      class={["bb-edit-gap", @open? && "is-open"]}
      data-at={@at}
      data-editor-ui
      phx-click-away={@open? && JS.push("close_palette", value: %{at: @at})}
    >
      <button
        id={"section-add-at-#{@at}"}
        type="button"
        class="bb-edit-gap-add"
        phx-click={JS.push("palette", value: %{at: @at})}
        aria-haspopup="dialog"
        aria-expanded={to_string(@open?)}
        aria-controls={@open? && "section-palette"}
      >
        <span aria-hidden="true" class="text-[15px] leading-none">+</span> Add a section
      </button>

      <div
        :if={@open?}
        id="section-palette"
        role="dialog"
        aria-labelledby="section-palette-title"
        class={[
          "absolute top-6 left-1/2 z-10 max-h-[min(34rem,70vh)] w-[min(40rem,calc(100vw-2rem))] -translate-x-1/2",
          "overflow-y-auto overscroll-contain bg-bb-edit-ground p-2 font-bb-edit text-bb-edit-ink",
          "shadow-bb-edit-palette",
          "motion-safe:animate-[bb-edit-pop_160ms_var(--bb-edit-ease)]"
        ]}
      >
        <div class="flex items-center justify-between gap-4 pl-2">
          <h2 id="section-palette-title" class="bb-edit-type-label text-bb-edit-soft">
            Add a section here
          </h2>
          <button
            id="section-palette-close"
            type="button"
            phx-click={JS.push("close_palette", value: %{at: @at})}
            aria-label="Close the palette"
            class="grid size-9 cursor-pointer place-items-center rounded-full text-bb-edit-soft transition-colors duration-[var(--bb-edit-duration)] ease-bb-edit hover:bg-bb-edit-ground-alt hover:text-bb-edit-ink pointer-coarse:size-11"
          >
            <Billboard.Sections.Icons.icon name="hero-x-mark-mini" class="size-4" />
          </button>
        </div>

        <section
          :for={{category, options} <- @add.palette}
          aria-labelledby={"section-palette-category-#{category}"}
          class="mt-2 first-of-type:mt-0"
        >
          <h3
            id={"section-palette-category-#{category}"}
            class="px-2 pt-2 pb-1 text-[11px] font-semibold tracking-[0.08em] text-bb-edit-soft uppercase"
          >
            {Catalogue.category_label(category)}
          </h3>
          <div class="grid gap-0.5 sm:grid-cols-2">
            <button
              :for={option <- options}
              id={"section-palette-#{option.entry.key}"}
              type="button"
              phx-click={!option.disabled && "add_section"}
              phx-value-component={option.entry.key}
              phx-value-at={@at}
              aria-disabled={option.disabled && "true"}
              class={[
                "group flex min-h-14 cursor-pointer items-center gap-3 rounded-[6px] p-2 text-left",
                "transition-colors duration-[var(--bb-edit-duration)] ease-bb-edit",
                "hover:bg-bb-edit-ground-alt focus-visible:bg-bb-edit-ground-alt focus-visible:outline-2 focus-visible:outline-bb-edit",
                "aria-disabled:cursor-default aria-disabled:hover:bg-transparent"
              ]}
            >
              <span
                class="flex h-8 w-12 shrink-0 border border-bb-glyph-line bg-bb-glyph-paper p-1 transition-transform duration-[var(--bb-edit-duration)] ease-bb-edit group-hover:-translate-y-px group-aria-disabled:translate-y-0 group-aria-disabled:opacity-50"
                aria-hidden="true"
              >
                <Sections.glyph section={option.glyph} library={@add.library} class="flex-1" />
              </span>
              <span class="min-w-0">
                <span class={[
                  "block text-[14px] font-semibold",
                  if(option.disabled, do: "text-bb-edit-disabled", else: "text-bb-edit-ink")
                ]}>
                  {option.entry.label}
                </span>
                <span class="block text-[12px] leading-snug text-bb-edit-soft">
                  {option.disabled || option.entry.hint}
                </span>
              </span>
            </button>
          </div>
        </section>
      </div>
    </div>
    """
  end
end
