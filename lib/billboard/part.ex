defmodule Billboard.Part do
  @moduledoc """
  A site's own part: an embedded resource a component holds, one or in a
  list, which the page editor can change. Billboard's parts (head,
  action, link, photo, point, detail, and quote) carry their editor
  fields in billboard. A site's part declares its own, as a component
  does, and the item a new one starts as:

      defmodule MySite.Sections.Faq.Question do
        use Billboard.Part

        part do
          blank %{title: "Your question"}
        end

        editor do
          words :title, label: "Question", limit: 80
          words :body, as: :markdown, label: "Answer", limit: 400
        end

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false, public?: true
          attribute :body, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end
      end

  A component names it in its parts and in its editor:
  `parts :questions, MySite.Sections.Faq.Question, min: 1` and
  `field :questions, as: :list, part: MySite.Sections.Faq.Question`.

  The `editor` section takes what a component's does
  (`Billboard.Component`, "How the editor changes it"). Its words are
  typed in place, at the item's path, such as `questions.0.title`, and
  its other fields are drawn in the item's tools. `blank` must pass the
  part's validations, since a new item is built from it; its keys are
  checked as the part compiles. Its words are filler the editor warns
  about until they're written over (`Billboard.EditorLive.Filler`).

  An item's tools change words, selects, toggles, numbers, a choice, a
  surface, and a part, and show notes; the rest of what a component's
  `editor` takes (a photograph, variants, a list, several choices,
  `bound:`) belongs to a section, and the part's checks refuse it.

  A part needs a primary read, create, and update action, which its
  `defaults` give, and its checks refuse one without them. A part in a
  list needs an id and a primary destroy action too, as
  `Billboard.Component` explains. `use Billboard.Part` sets
  `data_layer: :embedded` itself, and adds nothing else.
  """

  @doc false
  defmacro __using__(opts) do
    if Keyword.has_key?(opts, :data_layer) do
      raise ArgumentError,
            "a billboard part is an embedded resource, so `use Billboard.Part` sets " <>
              "`data_layer: :embedded` itself. Take `data_layer:` out."
    end

    {extensions, opts} = Keyword.pop(opts, :extensions, [])

    quote do
      use Ash.Resource,
          unquote(
            Keyword.merge(
              [data_layer: :embedded, extensions: [Billboard.Part.Dsl | extensions]],
              opts
            )
          )
    end
  end
end
