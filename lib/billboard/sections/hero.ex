defmodule Billboard.Sections.Hero do
  @moduledoc """
  The stock hero's renderer. Its `render/1` draws the inside of the
  page's hero block, which `Billboard.Sections.page/1` draws in the
  layout's hero slot, never in `<main>`, from the slots below: the
  heading, eyebrow, lede, size, actions, and photograph.

  The content's own words are Markdown. A bound hero takes its words
  from its binding (`ctx.context.bindings`, by the hero's `bind`,
  `Billboard.Context`): its heading, eyebrow, and lede, its photograph's
  label, and the seed of its placeholder. It keeps its own words
  wherever the binding gives none, and all of them with nothing to bind
  to.

  In the open section, the content's own words are drawn through
  `Billboard.Sections.Words`, to be typed into, and an empty eyebrow or
  lede is drawn too. Words the hero takes from its binding aren't, and
  neither are a hero's own words while its binding replaces them
  (`Billboard.Context.replaces_words?/1`), since the editor hides them
  and takes no words there.
  """
  use Billboard.Renderer

  alias Billboard.{Context, Markdown}
  alias Billboard.Components.Hero

  @doc """
  The inside of the page's hero block, which `Billboard.Sections.page/1`
  draws in the layout's hero slot, never in `<main>`, inside the
  `<section id="page-hero">` it keeps for the editor's marks: the
  eyebrow, the H1, the lede, and the actions, in `#main`, and the
  photograph beside them (`media/2`).

  It's given the hero as `section`, its `content` as it's drawn, and
  `ctx`, or, for a version with no hero, as the shared library has, a
  nil `section` and the page's `heading` and `lede`, which it draws in
  the hero's place.
  """
  def render(assigns) do
    %{section: section, ctx: ctx} = assigns
    # Drawn with what the site offers; the editor's marks, round it,
    # keep the section as it's stored.
    hero = section && put_in(section.content.value, assigns.content)

    assigns =
      assign(assigns,
        hero: hero,
        hero_heading: if(section, do: heading(hero, ctx), else: assigns[:heading]),
        hero_eyebrow: eyebrow(hero, ctx),
        hero_size: size(hero, ctx),
        hero_lede: if(section, do: lede(hero, ctx), else: assigns[:lede]),
        hero_media: media(hero, ctx)
      )

    ~H"""
    <div
      data-hero-media={@hero_media}
      class={[
        "bb-wrap grid items-center gap-12 md:gap-18",
        @hero_media == "right" && "md:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]",
        @hero_media == "left" && "md:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)]"
      ]}
    >
      <%!-- The skip link lands on the H1, so keyboard users skip the
      nav but still hear what page they are on; it stays on the text
      column when the hero is mirrored. --%>
      <div id="main" tabindex="-1" class="outline-none">
        <%!-- Kept from the formatter: with its hook, this tag passes the
        line length, and the formatter would put the eyebrow's words on a
        line of their own, with whitespace round them that would become
        part of its text. --%>
        <p :if={@hero_eyebrow} class="bb-eyebrow bb-type-eyebrow mb-6" phx-no-format>{@hero_eyebrow}</p>
        <h1 class={[
          "bb-title bb-measure-title text-bb-title",
          if(@hero_size == "display", do: "bb-type-display", else: "bb-type-title")
        ]}>
          {@hero_heading}
        </h1>
        <div :if={@hero_lede} class="bb-type-lead bb-measure mt-6 text-bb-ink">
          {@hero_lede}
        </div>
        <div
          :if={actions?(@hero, @ctx)}
          class="mt-12 flex flex-wrap items-center gap-4"
        >
          <.actions section={@hero} ctx={@ctx} />
        </div>
      </div>
      <div :if={@hero_media != "none"} {aside_attrs(@hero_media)}>
        <.media_slot section={@hero} ctx={@ctx} />
      </div>
    </div>
    """
  end

  # A mirrored hero puts its aside first on wide screens. Otherwise the
  # aside takes no class at all, as it always has.
  defp aside_attrs("left"), do: [class: "md:order-first"]
  defp aside_attrs(_media), do: []

  @doc """
  The hero's glyph: a dark block with two lines of words, and a
  photograph on the side its variant says.
  """
  def glyph(assigns) do
    ~H"""
    <span class="flex flex-1 gap-1.5 bg-bb-glyph-ink p-1">
      <Glyph.photo :if={@content.variant == :media_left} class="w-2/5" />
      <Glyph.bars on_dark class="flex-1" />
      <Glyph.photo :if={@content.variant == :media_right} class="w-2/5" />
    </span>
    """
  end

  @doc """
  The H1's contents: the binding's heading, as plain text, or the
  content's heading as Markdown.
  """
  def heading(nil, _ctx), do: nil

  def heading(section, ctx) do
    hero = hero(section)

    case heading_source(hero, ctx) do
      {:plain, text} -> text
      {:markdown, text} -> own_words(hero, ctx, "heading", text)
    end
  end

  @doc """
  The heading of `version`'s hero as plain text, for the browser title:
  the binding's heading, or the content's heading without its Markdown.
  Nil when the version has no hero.
  """
  @spec title(map(), map()) :: String.t() | nil
  def title(version, ctx \\ %{})

  def title(%{sections: [%{content: %{type: :hero}} = section | _]}, ctx) do
    case heading_source(hero(section), ctx) do
      {:plain, text} -> text
      {:markdown, nil} -> nil
      {:markdown, text} -> Markdown.plain(text)
    end
  end

  def title(_version, _ctx), do: nil

  @doc "The eyebrow over the H1, or nil."
  def eyebrow(nil, _ctx), do: nil

  def eyebrow(section, ctx) do
    hero = hero(section)

    case bound(hero, ctx) do
      %{eyebrow: eyebrow} -> blank_to_nil(eyebrow)
      _ -> own_words(hero, ctx, "eyebrow", hero.eyebrow, placeholder: "Eyebrow (optional)")
    end
  end

  @doc """
  The opening lines, or nil. An `:auto` hero shortens its own lede past
  `Billboard.Components.Hero.lede_limit/0`, except in the open section,
  which shows them in full.
  """
  def lede(nil, _ctx), do: nil

  def lede(section, ctx) do
    hero = hero(section)
    limit = if hero.size == :auto, do: [limit: Hero.lede_limit()], else: []
    opts = [placeholder: "Opening lines (optional)"] ++ limit

    case bound(hero, ctx) do
      %{lede: lede} -> markdown(lede)
      _ -> own_words(hero, ctx, "lede", hero.lede, opts)
    end
  end

  @doc """
  `"display"` or `"h1"`. `:auto` sets the heading at display size until it
  reads longer than `Billboard.Components.Hero.heading_limit/0`.
  """
  def size(nil, _ctx), do: "h1"

  def size(section, ctx) do
    hero = hero(section)

    case hero.size do
      :display -> "display"
      :h1 -> "h1"
      :auto -> if long?(heading_source(hero, ctx)), do: "h1", else: "display"
    end
  end

  @doc """
  Where the photograph sits: `"right"`, `"left"`, or `"none"` for a text
  only hero, or one with no photograph to show.
  """
  def media(nil, _ctx), do: "none"

  def media(section, ctx) do
    hero = hero(section)

    cond do
      hero.variant == :text_only -> "none"
      is_nil(photo_label(hero, ctx)) -> "none"
      hero.variant == :media_left -> "left"
      true -> "right"
    end
  end

  @doc """
  Whether the hero has actions to show: any, or, in the open hero, a way
  to add one.
  """
  def actions?(section, ctx \\ %{})
  def actions?(nil, _ctx), do: false
  def actions?(section, ctx), do: hero(section).actions != [] or Words.editing?(ctx)

  @doc """
  The hero's actions. The page lays them out in a row, so they are
  drawn straight into it, on the hero's surface, with the id prefix
  `"hero"` (`Billboard.Sections.Parts.action/1`). In the open hero, they
  are the editor's to change, and to add to (see `actions?/2`).
  """
  attr :section, :map, required: true
  attr :ctx, :map, required: true

  def actions(assigns) do
    actions = hero(assigns.section).actions

    assigns =
      assign(assigns,
        actions: actions,
        add?:
          Words.editing?(assigns.ctx) and
            length(actions) < EditorFields.narrowed(:hero)[:actions][:max]
      )

    ~H"""
    <Parts.editable_action
      :for={{action, i} <- Enum.with_index(@actions)}
      ctx={@ctx}
      path={"actions.#{i}"}
    >
      <Parts.action action={action} ctx={@ctx} prefix="hero" />
    </Parts.editable_action>
    <Parts.add_button :if={@add?} path="actions" />
    """
  end

  @doc """
  The photograph, at 4:3. A bound hero seeds the placeholder with its
  binding's seed, such as a product's slug, so each product's page has
  its own. In the open hero, it has its tools over it
  (`Billboard.Sections.Parts.editable_photo/1`).
  """
  attr :section, :map, required: true
  attr :ctx, :map, required: true

  def media_slot(assigns) do
    hero = hero(assigns.section)

    assigns =
      assign(assigns,
        photo: hero.photo || %{path: nil, alt: nil},
        label: photo_label(hero, assigns.ctx),
        seed: get_in(bound(hero, assigns.ctx) || %{}, [:seed])
      )

    ~H"""
    <Parts.editable_photo ctx={@ctx} photo={@photo}>
      <Blocks.photo
        src={@photo.path}
        alt={@photo.alt || ""}
        label={@label}
        seed={@seed}
        ratio="aspect-[4/3]"
      />
    </Parts.editable_photo>
    """
  end

  defp hero(%{content: %{value: hero}}), do: hero

  # What the hero's binding gives it on this page, from
  # `ctx.context.bindings`, or nil: a hero bound to nothing, or to
  # something this page hasn't got, draws its own words.
  defp bound(%{bind: :none}, _ctx), do: nil
  defp bound(%{bind: bind}, ctx), do: get_in(ctx, [:context, :bindings, bind])

  defp heading_source(hero, ctx) do
    case bound(hero, ctx) do
      %{heading: text} when is_binary(text) -> {:plain, text}
      _ -> {:markdown, hero.heading}
    end
  end

  defp long?({:plain, text}), do: String.length(text || "") > Hero.heading_limit()
  defp long?({:markdown, text}), do: String.length(Markdown.plain(text)) > Hero.heading_limit()

  defp photo_label(hero, ctx) do
    own = hero.photo && hero.photo.label

    case bound(hero, ctx) do
      %{photo_label: label} when is_binary(label) -> label
      _ -> own
    end
  end

  # The content's own words at `path`: in the open section, words to
  # type into, even when empty; elsewhere, as visitors see them, which
  # `Billboard.Sections.Words` marks with their path in the editor. A
  # hero whose binding replaces its words hides them from the editor, so
  # they're never typed into or marked.
  defp own_words(hero, ctx, path, text, opts \\ []) do
    cond do
      Context.replaces_words?(hero.bind) -> markdown(text, Keyword.take(opts, [:limit]))
      Words.editing?(ctx) -> Words.text(ctx, path, text, opts)
      text in [nil, ""] -> nil
      true -> Words.text(ctx, path, text, Keyword.take(opts, [:limit]))
    end
  end

  defp markdown(text, opts \\ [])
  defp markdown(text, _opts) when text in [nil, ""], do: nil
  defp markdown(text, opts), do: Markdown.inline(text, opts)

  defp blank_to_nil(text) when text in [nil, ""], do: nil
  defp blank_to_nil(text), do: text
end
