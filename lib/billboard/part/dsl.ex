defmodule Billboard.Part.Dsl do
  @moduledoc """
  The Spark extension behind `use Billboard.Part`: the `part` section,
  and the `editor` section a component has, with the checks on both.
  `Billboard.Part` documents them.
  """

  @part %Spark.Dsl.Section{
    name: :part,
    describe: "What billboard needs to know of a site's part.",
    examples: [
      """
      part do
        blank %{title: "Your question"}
      end
      """
    ],
    schema: [
      blank: [
        type: :map,
        default: %{},
        doc:
          "What a new item holds when the admin adds one, by field. It must pass the part's " <>
            "validations, and its words are filler the editor warns about until they're written over."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@part, Billboard.Component.Dsl.editor_section()],
    verifiers: [
      Billboard.Component.Verifiers.VerifyEditor,
      Billboard.Part.Verifiers.VerifyEditorKinds,
      Billboard.Part.Verifiers.VerifyActions,
      Billboard.Part.Verifiers.VerifyBlank
    ]
end
