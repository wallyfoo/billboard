defmodule Billboard.Component.Dsl do
  @moduledoc """
  The Spark extension behind `use Billboard.Component`: the `component`
  section, and the transformers and verifiers that turn it into an Ash
  embedded resource the builder can rely on. `Billboard.Component`
  documents the options.
  """

  @component %Spark.Dsl.Section{
    name: :component,
    describe: "What the page builder knows about this section type.",
    examples: [
      """
      component do
        key :banner
        label "Banner"
        hint "One idea, set apart."
        category :band
        kinds [:free]
        max 2
        mirror? true
        surface_kind :stand_out
        placeholder %{heading: "Your banner"}
      end
      """
    ],
    schema: [
      key: [
        type: :atom,
        required: true,
        doc: "The union tag, and the type name stored in content."
      ],
      label: [type: :string, required: true, doc: "The palette's name for it."],
      hint: [type: :string, required: true, doc: "The palette's one line about it."],
      category: [type: :atom, required: true, doc: "Its palette group."],
      kinds: [
        type: {:or, [{:in, [:all]}, {:list, :atom}]},
        default: :all,
        doc: "The page kinds that may use it, or `:all`."
      ],
      max: [
        type: {:or, [:pos_integer, nil]},
        default: nil,
        doc: "How many a page may hold, or `nil` for any number."
      ],
      column?: [type: :boolean, default: false, doc: "Whether it fits in a column."],
      mirror?: [
        type: :boolean,
        default: false,
        doc: "Whether it has image-left and image-right variants."
      ],
      surface_kind: [type: :atom, default: :page, doc: "Its kind in `Billboard.Surfaces`."],
      surface_from: [
        type: {:in, [nil, :library, :layout]},
        default: nil,
        doc:
          "Where it takes its surface from when it doesn't choose one: `nil` for its own " <>
            "or its parent's, `:library` for a library section's, or `:layout` for the layout's."
      ],
      placeholder: [
        type: :map,
        default: %{},
        doc: "What a new section starts with in the editor, by attribute."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@component],
    transformers: [
      Billboard.Component.Transformers.AddTag,
      Billboard.Component.Transformers.AddActions
    ],
    verifiers: [
      Billboard.Component.Verifiers.VerifyTag,
      Billboard.Component.Verifiers.VerifyPlaceholder
    ]
end
