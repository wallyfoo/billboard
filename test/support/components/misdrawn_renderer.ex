defmodule Billboard.Test.MisdrawnRenderer do
  @moduledoc """
  Draws `Billboard.Test.Misdrawn`, as a renderer should, but for the
  faults a test names with `misdraw!/1`:

    * `:unguarded_tools`: each point's tools drawn for a visitor too;
    * `:no_item_tools`: no point's tools;
    * `:bare_actions`: the buttons drawn without the editor's mark;
    * `:own_head`: the head's words drawn by hand, without its action;
    * `:bare_links`: a point's link drawn without the editor's mark, and
      no way to add one;
    * `:bare_photo`: the photograph drawn without its tools;
    * `:wrong_words`: the title typed in place with other words;
    * `:hidden_words`: the title drawn only in the open section;
    * `:no_id`: the outer element's id as `data-id`;
    * `:raises`: a raise for a visitor;
    * `:raises_open`: a raise in the open section;
    * `:raises_connected`: a raise in the open section, in the LiveView's
      own process only, not the test's;
    * `:reads_database`: a query, in the open section, in the LiveView's
      own process only;
    * `:glyph_raises` and `:glyph_text`: a glyph that raises, and one
      that draws words but no element.
  """
  use Billboard.Renderer

  @doc """
  Makes the renderer draw with `faults` until the test ends. The test
  module must not be async.
  """
  def misdraw!(faults) do
    Billboard.Test.Env.put_env_for_test(:billboard, __MODULE__, faults: faults, test: self())
  end

  defp faults, do: Application.get_env(:billboard, __MODULE__, [])[:faults] || []

  # Whether this is the LiveView's own process, not the test's, where
  # `Phoenix.LiveViewTest` draws the page first.
  defp connected?, do: self() != Application.get_env(:billboard, __MODULE__, [])[:test]

  def render(assigns) do
    faults = faults()
    editing? = Words.editing?(assigns.ctx)
    fail!(faults, editing?)

    assigns =
      assign(assigns,
        faults: faults,
        editing?: editing?,
        outer:
          if(:no_id in faults,
            do: %{"data-id" => assigns.anchor},
            else: %{"id" => assigns.anchor}
          ),
        title:
          if(editing? and :wrong_words in faults,
            do: "Other words",
            else: assigns.content.title
          ),
        count: length(assigns.content.points),
        spec: if(editing?, do: EditorFields.narrowed(:misdrawn)[:points], else: [])
      )

    ~H"""
    <section data-surface={@ctx.surface} class={Parts.section_class(@ctx)} {@outer}>
      <%= if :own_head in @faults do %>
        <div :if={@content.head}>
          <p :if={@editing?}>{Words.text(@ctx, "head.eyebrow", @content.head.eyebrow)}</p>
          <h2>{Words.text(@ctx, "head.heading", @content.head.heading)}</h2>
        </div>
      <% else %>
        <Parts.head head={@content.head} ctx={@ctx} prefix={@anchor} />
      <% end %>
      <h3 :if={@editing? or :hidden_words not in @faults}>{Words.text(@ctx, "title", @title)}</h3>
      <div :for={{point, i} <- Enum.with_index(@content.points)} class="relative">
        <h4>{Words.text(@ctx, "points.#{i}.title", point.title)}</h4>
        <p :if={point.body || @editing?}>{Words.text(@ctx, "points.#{i}.body", point.body)}</p>
        <%= cond do %>
          <% point.link && :bare_links in @faults -> %>
            <.bb_link navigate={point.link.path}>{point.link.label}</.bb_link>
          <% point.link -> %>
            <Parts.editable_action ctx={@ctx} path={"points.#{i}.link"}>
              <.bb_link navigate={point.link.path}>{point.link.label}</.bb_link>
            </Parts.editable_action>
          <% @editing? and :bare_links not in @faults -> %>
            <Parts.add_button path={"points.#{i}.link"} words="Add a link" />
          <% true -> %>
        <% end %>
        <Parts.item_tools
          :if={(@editing? or :unguarded_tools in @faults) and :no_item_tools not in @faults}
          path="points"
          index={i}
          count={@count}
          spec={@spec}
        />
      </div>
      <%= if :bare_actions in @faults do %>
        <div>
          <Parts.action :for={action <- @content.actions} action={action} ctx={@ctx} />
          <Parts.add_button :if={@editing? and length(@content.actions) < 2} path="actions" />
        </div>
      <% else %>
        <Parts.action_group
          actions={@content.actions}
          ctx={@ctx}
          prefix={@anchor}
          max={if(@editing?, do: 2)}
        />
      <% end %>
      <%= if :bare_photo in @faults do %>
        <div class="aspect-[4/3]"></div>
      <% else %>
        <Parts.editable_photo ctx={@ctx} photo={@content.photo}>
          <div class="aspect-[4/3]"></div>
        </Parts.editable_photo>
      <% end %>
    </section>
    """
  end

  defp fail!(faults, editing?) do
    cond do
      :raises in faults and not editing? ->
        raise "misdrawn for a visitor"

      :raises_open in faults and editing? ->
        raise "misdrawn in the open section"

      :raises_connected in faults and editing? and connected?() ->
        raise "misdrawn in the open section, once connected"

      :reads_database in faults and editing? and connected?() ->
        Billboard.Test.Repo.query!("SELECT 1")

      true ->
        :ok
    end
  end

  def glyph(assigns) do
    faults = faults()

    cond do
      :glyph_raises in faults -> raise "misdrawn glyph"
      :glyph_text in faults -> ~H"a sketch"
      true -> ~H|<Glyph.bars class="flex-1" />|
    end
  end
end
