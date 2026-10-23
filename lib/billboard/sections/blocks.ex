defmodule Billboard.Sections.Blocks do
  @moduledoc """
  The larger pieces stock sections are drawn from: a section's head, the
  band, a photograph slot, and a block of reviews. Their eyebrows,
  headings, and photographs carry the hook classes `Billboard.Sections.Parts`
  lists, which have no styles of their own.
  """
  # Bare `Phoenix.Component`: a site's own helpers aren't billboard's to
  # use.
  use Phoenix.Component

  alias Billboard.Sections.{Parts, Voronoi}
  alias Phoenix.LiveView.JS

  @doc """
  Sections open with a hairline rule; an optional caps eyebrow sits above the
  H2, and one quiet action may sit opposite. A head nested under another
  section's head takes `tag="h3"`, at the same size.
  """
  attr :eyebrow, :any, default: nil
  attr :heading, :any, required: true
  attr :tag, :string, values: ~w(h2 h3), default: "h2"
  attr :id, :string, default: nil
  attr :class, :any, default: nil
  slot :action

  def section_head(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "bb-section-head bb-rule-top mb-8 flex flex-wrap items-baseline gap-x-8 gap-y-2",
        "pt-[var(--bb-rule-gap,1.5rem)]",
        @class
      ]}
    >
      <div>
        <p :if={@eyebrow} class="bb-eyebrow bb-type-eyebrow mb-3">{@eyebrow}</p>
        <.dynamic_tag tag_name={@tag} class="bb-heading bb-type-heading text-bb-heading">
          {@heading}
        </.dynamic_tag>
      </div>
      <div :if={@action != []} class="ml-auto">{render_slot(@action)}</div>
    </div>
    """
  end

  @doc """
  A full-bleed band on a stand-out surface, which `surface` names: it
  carries `bb-surface-NAME` and `data-surface`, and the surface sets the
  ground, the ink, and the actions' tokens for everything in it. A band
  carries a single idea and one action, never a grid. It keeps its own
  padding, even beside a band on the same surface, since each band is
  meant to stand alone; and it never sits directly against the page hero.

  The idea is either a `heading` or a `:quote`. A quote sits in the wider left
  column, with the supporting copy and the action beside it; `quote_side`
  `"right"` mirrors that on wider screens. The supporting copy is the inner
  block, or `body` when it may be empty.

  ## Examples

  From a section that aliases this module and imports
  `Billboard.Sections.Buttons`, with `bb_button/1` as the action, and a
  site whose stand-out surface is `night`. The surface sets the button's
  tokens, so it needs nothing to say it's on the band:

      <Blocks.band surface="night" eyebrow="Workshops" heading="Learn it here">
        Classes every week, for beginners and the rest.
        <:action><.bb_button variant="secondary" navigate="/workshops">About the workshops</.bb_button></:action>
      </Blocks.band>

      <Blocks.band surface="night">
        <:quote name="Sam" meta="Owner">The same care, every visit.</:quote>
        We look after our regulars over years rather than one visit.
      </Blocks.band>
  """
  attr :surface, :string, required: true, doc: "the name of the surface it's drawn on"
  attr :eyebrow, :any, default: nil
  attr :heading, :any, default: nil
  attr :body, :any, default: nil, doc: "the supporting copy, in place of the inner block"
  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :quote_side, :string, values: ~w(left right), default: "left"
  slot :inner_block

  slot :quote do
    attr :name, :any, doc: "a string, or the editor's words"
    attr :meta, :any, doc: "a string, or the editor's words"
  end

  slot :action

  def band(assigns) do
    assigns = assign(assigns, :body?, assigns.body != nil or assigns.inner_block != [])

    ~H"""
    <section
      id={@id}
      data-surface={@surface}
      class={["bb-surface-#{@surface} bb-section-pad", @class]}
    >
      <div
        data-quote-side={if(@quote != [], do: @quote_side)}
        class={[
          "bb-wrap grid items-start",
          cond do
            @quote == [] -> "gap-6"
            @quote_side == "right" -> "gap-12 md:grid-cols-[minmax(0,1fr)_minmax(0,1.3fr)] md:gap-18"
            true -> "gap-12 md:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)] md:gap-18"
          end
        ]}
      >
        <div
          :if={@quote != [] || @eyebrow || @heading}
          class={if(@quote != [] && @quote_side == "right", do: "md:order-last")}
        >
          <p :if={@eyebrow} class="bb-eyebrow bb-type-eyebrow mb-6">{@eyebrow}</p>
          <h2 :if={@heading} class="bb-heading bb-type-title bb-measure-title text-bb-heading">
            {@heading}
          </h2>
          <Parts.quote_figure :for={quote <- @quote} name={quote[:name]} meta={quote[:meta]}>
            {render_slot(quote)}
          </Parts.quote_figure>
        </div>
        <div :if={@body? || @action != []}>
          <div :if={@body?} class="bb-type-body bb-measure text-bb-ink">
            {@body}{render_slot(@inner_block)}
          </div>
          <div :if={@action != []} class={if(@quote == [], do: "mt-12", else: "mt-6")}>
            {render_slot(@action)}
          </div>
        </div>
      </div>
    </section>
    """
  end

  @doc """
  A photograph slot at a fixed ratio. Uploaded images fill it with a centre
  crop, so a portrait photo in a landscape slot still fits; with no image it
  shows Voronoi noise in the site's noise colours, seeded by the label,
  with the label describing the shot on top. Never stock photography.
  """
  attr :src, :string, default: nil
  attr :alt, :string, default: ""
  attr :label, :string, required: true, doc: "what the photograph shows"
  attr :seed, :string, default: nil, doc: "sets the placeholder pattern; defaults to the label"
  attr :ratio, :string, default: "aspect-[3/2]"
  attr :caption, :string, default: nil
  attr :class, :any, default: nil

  def photo(assigns) do
    ~H"""
    <figure class={["bb-photo", @class]}>
      <div class={[@ratio, "relative overflow-hidden rounded-bb-photo bg-bb-placeholder"]}>
        <img :if={@src} src={@src} alt={@alt} class="size-full object-cover" loading="lazy" />
        <.voronoi_noise :if={!@src} seed={@seed || @label} />
        <div :if={!@src} class="relative flex size-full items-center justify-center p-6 text-center">
          <span class="bb-type-label bg-bb-placeholder-chip px-3 py-2 text-bb-placeholder-ink">
            {@label}
          </span>
        </div>
      </div>
      <figcaption :if={@caption} class="bb-type-small mt-3 text-bb-ink-soft">{@caption}</figcaption>
    </figure>
    """
  end

  @doc """
  Voronoi noise in the site's noise colours, seeded by `seed`, filling the
  slot it sits in: what an empty photograph slot shows. It's public so a
  site may draw it too, as on a portrait.
  """
  attr :seed, :string, required: true
  attr :count, :integer, default: 24

  def voronoi_noise(assigns) do
    assigns = assign(assigns, :cells, Voronoi.cells(assigns.seed, assigns.count))

    ~H"""
    <svg
      viewBox={"0 0 #{Voronoi.size()} #{Voronoi.size()}"}
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
      class="absolute inset-0 size-full"
    >
      <polygon
        :for={cell <- @cells}
        points={cell.points}
        style={"fill: var(--bb-#{cell.colour}); stroke: var(--bb-#{cell.colour})"}
        stroke-width="0.3"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  @doc """
  Curated reviews, attributed by name and date only. Scales from one to many
  without a carousel: six show at first, and the rest reveal in place.
  A single review runs at display size.

  The `head` slot holds the section head.
  """
  attr :reviews, :list, required: true
  attr :initial, :integer, default: 6
  attr :id, :string, default: "reviews"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :head
  slot :note

  def review_block(%{reviews: []} = assigns), do: ~H""

  def review_block(assigns) do
    assigns = assign(assigns, :count, length(assigns.reviews))

    ~H"""
    <section id={@id} class={@class} {@rest}>
      {render_slot(@head)}
      <div class={[
        "grid gap-x-8",
        @count > 1 && "md:grid-cols-2 lg:grid-cols-3"
      ]}>
        <Parts.quote_figure
          :for={{review, index} <- Enum.with_index(@reviews)}
          id={"#{@id}-#{review.id}"}
          class={["py-6", index >= @initial && "hidden"]}
          data-overflow={index >= @initial}
          name={review.name}
          meta={Calendar.strftime(review.reviewed_on, "%B %Y")}
          body_class={["bb-measure", if(@count == 1, do: "bb-type-quote", else: "bb-type-subheading")]}
          caption_class="mt-4"
        >
          {review.quote}
        </Parts.quote_figure>
      </div>
      <button
        :if={@count > @initial}
        id={"#{@id}-show-all"}
        type="button"
        class="bb-type-label mt-6 min-h-11 cursor-pointer border-b border-bb-rule text-bb-link"
        phx-click={
          JS.remove_class("hidden", to: "##{@id} [data-overflow]")
          |> JS.hide()
        }
      >
        Show all {@count}
      </button>
      <p :if={@note != []} class="bb-type-small bb-measure mt-8 text-bb-ink-soft">
        {render_slot(@note)}
      </p>
    </section>
    """
  end
end
