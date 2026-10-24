defmodule MySiteWeb.Sections.Faq do
  @moduledoc """
  Draws a FAQ: its title, then each question with its answer. Folded,
  each answer opens under its question, in `<details>`. In the open
  section every answer shows, so each can be typed into.
  """
  use Billboard.Renderer

  # guide:render
  def render(assigns) do
    editing? = Words.editing?(assigns.ctx)

    assigns =
      assign(assigns,
        editing?: editing?,
        folded?: assigns.content.style == :folded and not editing?,
        count: length(assigns.content.questions),
        spec:
          if(editing?,
            do: EditorFields.narrowed(:faq)[:questions],
            else: []
          )
      )

    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <h2 :if={@content.title || @editing?} class="bb-heading bb-type-heading text-bb-heading">
        {Words.text(@ctx, "title", @content.title)}
      </h2>
      <div class="bb-measure mt-8">
        <.question
          :for={{question, i} <- Enum.with_index(@content.questions)}
          question={question}
          index={i}
          folded?={@folded?}
          ctx={@ctx}
        >
          <Parts.item_tools :if={@editing?} path="questions" index={i} count={@count} spec={@spec} />
        </.question>
      </div>
    </section>
    """
  end

  # guide:end

  # guide:question
  attr :question, :map, required: true
  attr :index, :integer, required: true
  attr :folded?, :boolean, required: true
  attr :ctx, :map, required: true
  slot :inner_block

  defp question(%{folded?: true} = assigns) do
    ~H"""
    <details class="bb-rule-top py-4">
      <summary class="bb-item-title bb-type-subheading cursor-pointer text-bb-subheading">
        {Words.text(@ctx, "questions.#{@index}.title", @question.title)}
      </summary>
      <div :if={@question.body} class="bb-type-body mt-3 text-bb-ink">
        {Words.text(@ctx, "questions.#{@index}.body", @question.body)}
      </div>
    </details>
    """
  end

  defp question(assigns) do
    ~H"""
    <div class={["bb-rule-top py-4", Words.editing?(@ctx) && "bb-edit-item"]}>
      <h3 class="bb-item-title bb-type-subheading text-bb-subheading">
        {Words.text(@ctx, "questions.#{@index}.title", @question.title)}
      </h3>
      <div :if={@question.body || Words.editing?(@ctx)} class="bb-type-body mt-3 text-bb-ink">
        {Words.text(@ctx, "questions.#{@index}.body", @question.body)}
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # guide:end

  # guide:glyph
  def glyph(assigns) do
    ~H"""
    <span class="grid flex-1 content-center gap-1 px-1">
      <span class="h-1.5 w-1/2 bg-bb-glyph-ink"></span>
      <span :for={_row <- 1..3} class="flex items-center gap-1.5 border-t border-bb-glyph-line pt-1">
        <span class="h-1 w-2/3 bg-bb-glyph-soft"></span>
      </span>
    </span>
    """
  end

  # guide:end
end
