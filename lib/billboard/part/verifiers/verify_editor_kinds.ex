defmodule Billboard.Part.Verifiers.VerifyEditorKinds do
  @moduledoc """
  Checks that a site's part's `editor` holds only what the editor can
  change in one of its items: words, selects, toggles, numbers, a
  choice, a surface, a part, and notes. A photograph, variants, a list,
  several choices, a Shared section's pick, or a binding's note belong
  to a section, and so does `bound: :hide`, since only a section has a
  binding. Each message names the fix. Its errors are compile warnings,
  as every Spark verifier's are.
  """
  use Spark.Dsl.Verifier

  alias Billboard.Component.Field
  alias Spark.Dsl.Verifier

  # The kinds the section editor saves in an item (its `@part_kinds`),
  # with a part, which it draws as the item's own, and a note.
  @kinds [:text, :markdown, :select, :toggle, :number, :choice, :surface, :part, :note]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    errors =
      for entry <- Verifier.get_entities(dsl_state, [:editor]),
          message <- kind(entry) ++ bound(entry) do
        Spark.Error.DslError.exception(
          module: module,
          path: [:editor, entry.name],
          location: Spark.Dsl.Entity.anno(entry),
          message: message
        )
      end

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp kind(%Field{as: as, name: name}) when as not in @kinds,
    do: [
      "`#{inspect(name)}` is `as: #{inspect(as)}` in a part's `editor`, but the editor " <>
        "changes a part's items with words, selects, toggles, numbers, a choice, a surface, " <>
        "a part, and notes only. Make it one of those, or take it out of `editor`, and give " <>
        "the section's component the field instead"
    ]

  defp kind(_entry), do: []

  defp bound(%{bound: :hide, name: name}),
    do: [
      "`#{inspect(name)}` is `bound: :hide` in a part's `editor`, but only a section's " <>
        "binding replaces its words, and a part has none. Take `bound:` out"
    ]

  defp bound(_entry), do: []
end
