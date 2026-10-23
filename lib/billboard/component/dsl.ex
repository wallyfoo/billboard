defmodule Billboard.Component.Dsl do
  @moduledoc """
  The Spark extension behind `use Billboard.Component`: the `component`
  and `editor` sections, and the transformers and verifiers that turn
  them into an Ash embedded resource the builder can rely on.
  `Billboard.Component` documents the options.
  """

  @part %Spark.Dsl.Entity{
    name: :part,
    describe: "One part, such as a heading or a photograph, held in an attribute of its own.",
    examples: ["part :head, MySite.Parts.Head"],
    target: Billboard.Component.Part,
    args: [:name, :type],
    identifier: :name,
    schema: [
      name: [type: :atom, required: true, doc: "The attribute's name."],
      type: [type: :module, required: true, doc: "The part's embedded resource."],
      allow_nil?: [type: :boolean, default: true, doc: "Whether the part may be left out."],
      default: [
        type: :any,
        doc: "What a new component holds in the part, such as `%MySite.Parts.Head{}`."
      ],
      description: [type: :string, doc: "The attribute's description."]
    ]
  }

  @parts %Spark.Dsl.Entity{
    name: :parts,
    describe: "A list of parts, such as a row of points, held in one attribute.",
    examples: ["parts :points, MySite.Parts.Point, min: 1, max: 3"],
    target: Billboard.Component.Parts,
    args: [:name, :type],
    identifier: :name,
    schema: [
      name: [type: :atom, required: true, doc: "The attribute's name."],
      type: [type: :module, required: true, doc: "Each item's embedded resource."],
      min: [type: :non_neg_integer, doc: "The fewest items the list may hold."],
      max: [type: :pos_integer, doc: "The most items the list may hold."],
      allow_nil?: [type: :boolean, default: false, doc: "Whether the list may be `nil`."],
      description: [type: :string, doc: "The attribute's description."]
    ]
  }

  @either [
    name: [type: :atom, required: true, doc: "The attribute it edits, or a note's own name."],
    label: [type: :string, doc: "What the editor calls it."],
    hint: [type: :string, doc: "A line under it."],
    hide_when: [
      type: :keyword_list,
      doc:
        "Leaves it out while another field holds one of some values, as " <>
          "`[variant: [:text_only]]`."
    ],
    more: [
      type: :boolean,
      default: false,
      doc: "Offers it under More…, for words a visitor sees only now and then."
    ],
    bound: [
      type: {:in, [nil, :hide]},
      default: nil,
      doc:
        "`:hide` leaves it out while the section's binding replaces its own words " <>
          "(`Billboard.Context`)."
    ]
  ]

  @field %Spark.Dsl.Entity{
    name: :field,
    describe:
      "A setting the editor draws in the section's controls, a note, or a part, list, or " <>
        "photograph it changes.",
    examples: [
      ~s(field :size, as: :select, label: "Heading size", options: [{"Auto", :auto}, {"Standard", :h1}]),
      ~s(field :actions, as: :list, part: :action, max: 3, item_label: "action")
    ],
    target: Billboard.Component.Field,
    args: [:name],
    identifier: :name,
    schema:
      @either ++
        [
          as: [
            type:
              {:in,
               [
                 :select,
                 :variants,
                 :toggle,
                 :number,
                 :note,
                 :binding_note,
                 :part,
                 :list,
                 :photo,
                 :choice,
                 :choices,
                 :surface,
                 :shared
               ]},
            required: true,
            doc: "What it is. `Billboard.Component` describes each."
          ],
          options: [
            type: :any,
            doc: "A select's `{label, value}` options, or the variants' layouts, in order."
          ],
          only_on: [
            type: :keyword_list,
            doc: "A select's options that go only on some page kinds, as `[visit: [:item]]`."
          ],
          min: [type: :integer, doc: "A number's least, or a list's fewest items."],
          max: [type: :integer, doc: "A number's most, or a list's most items."],
          part: [
            type: :atom,
            doc:
              "The part a part or list edits: `:action`, `:link`, `:head`, `:quote`, " <>
                "`:point`, or `:detail`."
          ],
          except: [
            type: {:list, :atom},
            default: [],
            doc: "The part's fields the editor leaves out here."
          ],
          optional: [type: :boolean, default: false, doc: "Whether a part can be taken away."],
          item_label: [
            type: :string,
            doc: ~s|What one of the part or list is called, as in "Add a point".|
          ],
          ratio: [type: :string, doc: "A photograph's shape, as a Tailwind aspect class."],
          text: [type: :string, doc: "A note's words."],
          link: [type: {:tuple, [:string, :string]}, doc: "A note's link, as `{words, path}`."],
          from: [type: :atom, doc: "A choice's set, by name (`Billboard.Context.choices/1`)."]
        ]
  }

  @words %Spark.Dsl.Entity{
    name: :words,
    describe: "Words the admin types in place, where the section draws them.",
    examples: [~s(words :heading, label: "Heading", limit: 60, accent: true)],
    target: Billboard.Component.Words,
    args: [:name],
    identifier: :name,
    schema:
      @either ++
        [
          as: [
            type: {:in, [:text, :markdown]},
            default: :text,
            doc: "`:text` for a line, or `:markdown` for words that may run to a few lines."
          ],
          limit: [
            type: :pos_integer,
            doc: "The soft limit the counter warns past, counted without the Markdown."
          ],
          accent: [
            type: :boolean,
            default: false,
            doc: "Hints that one word may be set in italic."
          ]
        ]
  }

  @editor %Spark.Dsl.Section{
    name: :editor,
    describe:
      "How the page editor changes the component: its settings, notes, parts, and lists " <>
        "(`field`), and the words typed in place (`words`), in the order the editor draws them.",
    examples: [
      """
      editor do
        field :variant, as: :variants, options: [:text_only, :media_right]
        words :heading, label: "Heading", limit: 60, accent: true
        field :actions, as: :list, part: :action, max: 2, item_label: "action"
      end
      """
    ],
    entities: [@field, @words]
  }

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
    entities: [@part, @parts],
    # Naming a module here makes no compile-time dependency on it, so a
    # component and its renderer can each change without recompiling the other.
    no_depend_modules: [:renderer, :rules],
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
      surface_kind: [
        type: :atom,
        default: :page,
        doc:
          "Its kind in `Billboard.Surfaces`. Never `:card`, which is the kind of a card " <>
            "inside a section."
      ],
      surface_from: [
        type: {:in, [nil, :library, :layout]},
        default: nil,
        doc:
          "Where it takes its surface from when it doesn't choose one: `nil` for its own " <>
            "or its parent's, `:library` for a library section's, or `:layout` for the layout's."
      ],
      renderer: [
        type: :module,
        doc: "Its renderer, a module that does `use Billboard.Renderer`."
      ],
      context: [
        type: {:wrap_list, :atom},
        default: [],
        doc:
          "The page context entries its renderer reads (`Billboard.Context`), such as " <>
            "`:bindings` or `:scope`."
      ],
      rules: [
        type: {:list, :module},
        default: [],
        doc: "Its own rules (`Billboard.Component.Rule`), run on each of its sections."
      ],
      filler?: [
        type: :boolean,
        default: true,
        doc:
          "Whether its placeholder is filler the editor warns about until it's written over. " <>
            "`false` for one that reads as finished words, such as \"What's on\"."
      ],
      placeholder: [
        type: :map,
        default: %{},
        doc: "What a new section starts with in the editor, by attribute."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@component, @editor],
    transformers: [
      Billboard.Component.Transformers.AddTag,
      Billboard.Component.Transformers.AddParts,
      Billboard.Component.Transformers.AddActions,
      Billboard.Component.Transformers.AddSiteOptions
    ],
    verifiers: [
      Billboard.Component.Verifiers.VerifyTag,
      Billboard.Component.Verifiers.VerifyActions,
      Billboard.Component.Verifiers.VerifyPlaceholder,
      Billboard.Component.Verifiers.VerifyParts,
      Billboard.Component.Verifiers.VerifySurfaceKind,
      Billboard.Component.Verifiers.VerifyEditor,
      Billboard.Component.Verifiers.VerifyRenderer
    ]
end
