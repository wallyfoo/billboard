defmodule Billboard.Components.Prices do
  @moduledoc """
  A price list: rows of what things cost, each a title and its price,
  from the site's own records. Billboard draws the rows; it never keeps
  or edits the prices themselves, which the site keeps, edits, and
  formats, and hands over through its `Billboard.Data` module
  (`Billboard.Sections.Prices` lists what each row holds). With no data
  module, or none for this component, it draws nothing.

  Its fields:

    * `head`, an optional `Billboard.Parts.Head`, "Prices" when it's
      added from the palette;
    * `body`, opening words (Markdown), with the head and the action
      beside the rows;
    * `actions`, up to one `Billboard.Parts.Action`, under the opening
      words;
    * `note`, words under the rows (Markdown);
    * `group`, one of the site's `:scope` choices (`Billboard.Context`),
      or none: with one, the section shows only that group's rows,
      wherever it is;
    * `this_page_only`, a toggle: with it on, and no `group`, the
      section shows only the rows whose group is the page's scope
      (`ctx.context.scope`), and none on a page about nothing. The
      editor hides it while a `group` is chosen, since the group wins.

  With neither, it shows every row. It reads the page's `:scope`, fits
  in a column, and isn't filler, so its placeholder isn't warned about.

  A site lists it in `use Billboard.Site`'s `components:` once its data
  module gives its rows:

      def fetch(%Billboard.Components.Prices{}, _context, loaded),
        do: Billboard.Data.once(loaded, :prices, &MySite.list_prices!/0)

  Billboard adds `component`, the union's tag, always `:prices`;
  `Billboard.Component` explains why every component has one.
  """
  use Billboard.Component

  component do
    key :prices
    label "Prices"
    hint "What things cost, from the site's price list."
    category :data
    renderer Billboard.Sections.Prices
    context [:scope]
    column? true
    filler? false
    placeholder %{head: %{heading: "Prices"}}

    part :head, Billboard.Parts.Head
    parts :actions, Billboard.Parts.Action, max: 1
  end

  # guide:editor
  editor do
    field :head, as: :part, part: :head, optional: true, item_label: "heading"
    words :body, as: :markdown, label: "Opening words", limit: 300
    field :actions, as: :list, part: :action, max: 1, item_label: "action"
    words :note, as: :markdown, label: "Note", limit: 200
    field :group, as: :choice, from: :scope, label: "Group"

    field :this_page_only,
      as: :toggle,
      label: "Only this page's group",
      hide_when: [group: :any]
  end

  # guide:end

  attributes do
    attribute :body, :string, public?: true, constraints: [max_length: 600]
    attribute :note, :string, public?: true, constraints: [max_length: 400]
    attribute :group, :string, public?: true
    attribute :this_page_only, :boolean, allow_nil?: false, default: false, public?: true
  end
end
