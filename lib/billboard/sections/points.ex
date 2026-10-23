defmodule Billboard.Sections.Points do
  @moduledoc """
  Short points side by side, in two, three, or four columns. Four
  columns are two on a middling screen and four on a wide one. In the
  rows look, each sits under a hairline. In the cards look, each is a
  bounded card (`bb-card`), with the site's corner and no hairline, since
  its edge already bounds it, and a card may sit on a surface of its own
  (`Surfaces.card/1`). A look or a number of columns the site doesn't
  offer arrives as the site's default (`Billboard.SiteOptions.resolved/2`). Under a
  section head the points' titles are `h3`s; with no head they are the
  section's `h2`s, set at the same size. A point's link is always a text
  link. In two columns, the points' words keep to a reading measure.

  In the open section, each point has its tools (`Parts.item_tools/1`),
  its link is the editor's to change, and a point without one offers to
  add one. Where the site offers cards a surface, each card has a Ground
  select for its own, which goes to the section's editor, as a detail's
  "Shows on" does.
  """
  use Billboard.Renderer

  alias Billboard.Surfaces

  def render(assigns) do
    editing? = Words.editing?(assigns.ctx)
    cards? = assigns.content.look == :cards
    columns = assigns.content.columns

    assigns =
      assign(assigns,
        title_tag: if(assigns.content.head, do: "h3", else: "h2"),
        grid: grid(columns),
        columns: columns,
        editing?: editing?,
        cards?: cards?,
        grounds: editing? and cards? and Surfaces.offered(:card) != [],
        # Each point, its place, and the surface its card is drawn on: nil
        # for its section's, and in the rows look, where there's no card.
        points:
          for(
            {point, i} <- Enum.with_index(assigns.content.points),
            do: {point, i, cards? && Surfaces.card(point.surface)}
          ),
        # Narrowing reads the site's options, which only the editor needs.
        spec: if(editing?, do: EditorFields.narrowed(:points)[:points], else: []),
        count: length(assigns.content.points)
      )

    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <Parts.head head={@content.head} ctx={@ctx} prefix={@anchor} />
      <div class={["grid gap-8", @grid]}>
        <div
          :for={{point, i, surface} <- @points}
          data-surface={surface}
          class={[
            if(@cards?,
              do: card_class(surface),
              else: "bb-point bb-rule-top pt-[var(--bb-rule-gap,1.5rem)]"
            ),
            @editing? && "bb-edit-item"
          ]}
        >
          <.dynamic_tag
            tag_name={@title_tag}
            class="bb-item-title bb-type-subheading text-bb-subheading"
          >
            {Words.text(@ctx, "points.#{i}.title", point.title)}
          </.dynamic_tag>
          <p
            :if={point.body || Words.editing?(@ctx)}
            class={["bb-type-body mt-3 text-bb-ink", @columns == 2 && "bb-measure"]}
          >
            {Words.text(@ctx, "points.#{i}.body", point.body, placeholder: "Words (optional)")}
          </p>
          <Parts.editable_action :if={point.link} ctx={@ctx} path={"points.#{i}.link"}>
            <.bb_link navigate={point.link.path} class="mt-3">
              {point.link.label}
            </.bb_link>
          </Parts.editable_action>
          <Parts.add_button
            :if={@editing? && !point.link}
            path={"points.#{i}.link"}
            words="Add a link"
            class="mt-3"
          />
          <.ground :if={@grounds} index={i} value={surface} />
          <Parts.item_tools :if={@editing?} path="points" index={i} count={@count} spec={@spec} />
        </div>
      </div>
    </section>
    """
  end

  # Each grid is named in full, for Tailwind to find.
  defp grid(2), do: "md:grid-cols-2"
  defp grid(3), do: "md:grid-cols-3"
  defp grid(4), do: "md:grid-cols-2 lg:grid-cols-4"

  # A card keeps the point's hook, and `bb-card` gives it its corner. Its
  # room inside is the site's `--bb-card-pad`, as a row's gap under its
  # hairline is `--bb-rule-gap`.
  defp card_class(nil), do: "bb-point bb-card p-[var(--bb-card-pad,1.5rem)]"
  defp card_class(surface), do: [card_class(nil), "bb-surface-#{surface}"]

  attr :index, :integer, required: true

  attr :value, :string,
    default: nil,
    doc: "the surface it's drawn on while the site offers it, or nil"

  # The card's own surface, or its section's, changed in place. It goes to
  # the section's editor, which saves it only when this select is what
  # changed. Its form holds nothing else, so another change never sends
  # it. A surface the site has stopped offering shows the section's
  # chosen, which is the ground the card is drawn on.
  defp ground(assigns) do
    labels = Map.new(Surfaces.all(), &{&1.name, &1.label})

    assigns =
      assign(assigns,
        id: "section-item-points-#{assigns.index}-surface",
        options: [
          {"Same as the section", ""}
          | Enum.map(Surfaces.offered(:card), &{Map.fetch!(labels, &1), &1})
        ]
      )

    ~H"""
    <.form
      for={%{}}
      id={@id}
      phx-change="edit_part"
      phx-target="#section-editor"
      class="bb-edit-item-ground"
      data-editor-ui
    >
      <input type="hidden" name="path" value={"points.#{@index}"} />
      <label for={"#{@id}-select"}>Ground</label>
      <select id={"#{@id}-select"} name={"section[content][points][#{@index}][surface]"}>
        {Phoenix.HTML.Form.options_for_select(@options, @value || "")}
      </select>
    </.form>
    """
  end

  @doc """
  The points' glyph: two, three, or four short columns under a hairline,
  as many as the section is drawn in.
  """
  def glyph(assigns) do
    assigns = assign(assigns, columns: assigns.content.columns)

    ~H"""
    <span class="grid flex-1 content-center gap-1.5 px-1">
      <span class="h-px w-full bg-bb-glyph-ink"></span>
      <span class={["grid gap-2", glyph_grid(@columns)]}>
        <Glyph.bars :for={_column <- 1..@columns//1} />
      </span>
    </span>
    """
  end

  defp glyph_grid(2), do: "grid-cols-2"
  defp glyph_grid(3), do: "grid-cols-3"
  defp glyph_grid(4), do: "grid-cols-4"
end
