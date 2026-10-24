defmodule Billboard.Component.Verifiers.VerifyParts do
  @moduledoc """
  Checks each part's type against the rules in `Billboard.Component`'s
  Parts section:

    * It must be an Ash resource with a primary destroy action, because
      Ash destroys the old value when a list item is dropped or an
      optional part is cleared, and raises when there's none.
    * In a `parts` list, it must have an `:id` primary key, because a list
      item without one is rebuilt from its params alone.

  And whatever declares them, a `part`, a `parts` list, or a plain
  attribute, a component's `:action` must hold `Billboard.Parts.Action`
  and its `:actions` a list of them, since billboard's rules read a
  section's buttons there (`Billboard.Rules.actions_of/1`).

  Its errors are compile warnings, as every Spark verifier's are.
  """
  use Spark.Dsl.Verifier

  alias Billboard.Component.Parts
  alias Spark.Dsl.Verifier

  # The attributes billboard's rules read a section's buttons from, and
  # the type each must have.
  @actions [
    action: {Billboard.Parts.Action, "button", "Billboard.Parts.Action", "part"},
    actions:
      {{:array, Billboard.Parts.Action}, "buttons", "a list of Billboard.Parts.Action", "parts"}
  ]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    parts =
      dsl_state
      |> Verifier.get_entities([:component])
      |> Enum.map(&{[:component, &1.name], &1, problem(&1)})

    actions =
      for {name, expected} <- @actions,
          attribute = Ash.Resource.Info.attribute(dsl_state, name),
          do: {[:attributes, name], attribute, action_problem(name, attribute, expected)}

    Enum.find_value(parts ++ actions, :ok, fn
      {_path, _entity, nil} ->
        nil

      {path, entity, message} ->
        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: path,
           location: Spark.Dsl.Entity.anno(entity),
           message: message
         )}
    end)
  end

  defp action_problem(name, attribute, {type, what, holding, entity}) do
    if held(attribute.type) == type,
      do: nil,
      else:
        "`#{inspect(name)}` is where billboard's rules read a section's #{what}, so it must " <>
          "hold #{holding}, as `#{entity} #{inspect(name)}, Billboard.Parts.Action` does. " <>
          "Rename it, or hold `Billboard.Parts.Action`."
  end

  # The type an attribute holds, through any name a site gives it of its
  # own (`Ash.Type.NewType`), in a list or not.
  defp held(type), do: type |> Ash.Type.get_type() |> Ash.Type.NewType.subtype_of()

  defp problem(part) do
    # Ash has already refused a type that isn't one, at transform time; a
    # short name like `:string` gets this far.
    type = Ash.Type.get_type(part.type)
    Code.ensure_compiled!(type)

    cond do
      not Spark.Dsl.is?(type, Ash.Resource) ->
        "#{inspect(type)} isn't an Ash resource, so it can't be a part. Make it an " <>
          "embedded resource: `use Ash.Resource, data_layer: :embedded`."

      is_nil(Ash.Resource.Info.primary_action(type, :destroy)) ->
        "#{inspect(type)} has no destroy action, and Ash destroys a part when it's " <>
          "dropped from a list. Add `defaults [:read, :destroy, create: :*, update: :*]` " <>
          "to its actions."

      match?(%Parts{}, part) and Ash.Resource.Info.primary_key(type) != [:id] ->
        "#{inspect(type)} sits in a list, so it needs `uuid_primary_key :id`: without " <>
          "one, a list change rebuilds every item from its params alone."

      true ->
        nil
    end
  end
end
