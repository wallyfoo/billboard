defmodule Billboard.Component.Verifiers.VerifyEditor do
  @moduledoc """
  Checks the `editor` section: each entry edits one of the component's
  attributes, but a note, which edits nothing; words edit a string; a
  part or list names its part; a choice names its set; and there's at
  most one set of several choices (`:choices`), since the editor keeps
  one a section, in the order it was ticked. Each message names the fix.
  Its errors are compile warnings, as every Spark verifier's are.
  """
  use Spark.Dsl.Verifier

  alias Billboard.Component.{Field, Words}
  alias Spark.Dsl.Verifier

  @notes [:note, :binding_note]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    attributes = Map.new(Ash.Resource.Info.attributes(dsl_state), &{&1.name, &1})
    entries = Verifier.get_entities(dsl_state, [:editor])

    messages =
      for(
        entry <- entries,
        message <- problems(entry, attributes, module),
        do: {entry, message}
      ) ++ second_choices(entries)

    errors =
      for {entry, message} <- messages do
        Spark.Error.DslError.exception(
          module: module,
          path: [:editor, entry.name],
          location: Spark.Dsl.Entity.anno(entry),
          message: message
        )
      end

    if errors == [], do: :ok, else: {:error, errors}
  end

  # The editor keeps one set of several choices a section, in the order
  # it was ticked, and draws it under one id, so a second is refused.
  defp second_choices(entries) do
    for %Field{as: :choices, name: name} = entry <- Enum.drop(choices(entries), 1),
        do:
          {entry,
           "`#{inspect(name)}` is a second set of several choices in `editor`, and the editor " <>
             "offers one a section. Make it a `:choice`, or take it out of `editor`"}
  end

  defp choices(entries), do: Enum.filter(entries, &match?(%Field{as: :choices}, &1))

  defp problems(%Field{as: as}, _attributes, _module) when as in @notes, do: []

  defp problems(entry, attributes, module) do
    name = entry.name

    case Map.fetch(attributes, name) do
      :error ->
        [
          "`#{inspect(name)}` is in `editor` but isn't an attribute of #{inspect(module)}. " <>
            "Add `attribute #{inspect(name)}, :string`, or take it out of `editor`"
        ]

      {:ok, attribute} ->
        words(entry, attribute) ++ part(entry) ++ from(entry)
    end
  end

  defp words(%Words{name: name}, %{type: type}) when type != Ash.Type.String,
    do: [
      "`#{inspect(name)}` is words in `editor`, but it isn't a string. Make it a `field`, " <>
        "or `#{inspect(name)}` a string attribute"
    ]

  defp words(_entry, _attribute), do: []

  defp part(%Field{as: as, part: nil, name: name}) when as in [:part, :list],
    do: [
      "`#{inspect(name)}` is a #{as} in `editor` but names no part. Add `part: :detail`, " <>
        "or the part it holds (`Billboard.Sections.Parts.editor_fields/1`)"
    ]

  defp part(_entry), do: []

  defp from(%Field{as: as, from: nil, name: name}) when as in [:choice, :choices],
    do: [
      "`#{inspect(name)}` is a choice in `editor` but names no set. Add `from: :scope`, " <>
        "or the set it picks from (`Billboard.Context.choices/1`)"
    ]

  defp from(_entry), do: []
end
