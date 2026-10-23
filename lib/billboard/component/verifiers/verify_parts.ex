defmodule Billboard.Component.Verifiers.VerifyParts do
  @moduledoc """
  Checks each part's type against the rules in `Billboard.Component`'s
  Parts section:

    * It must be an Ash resource with a primary destroy action, because
      Ash destroys the old value when a list item is dropped or an
      optional part is cleared, and raises when there's none.
    * In a `parts` list, it must have an `:id` primary key, because a list
      item without one is rebuilt from its params alone.

  Its errors are compile warnings, as every Spark verifier's are.
  """
  use Spark.Dsl.Verifier

  alias Billboard.Component.Parts
  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    dsl_state
    |> Verifier.get_entities([:component])
    |> Enum.find_value(:ok, fn part ->
      case problem(part) do
        nil ->
          nil

        message ->
          {:error,
           Spark.Error.DslError.exception(
             module: module,
             path: [:component, part.name],
             location: Spark.Dsl.Entity.anno(part),
             message: message
           )}
      end
    end)
  end

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
