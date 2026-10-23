defmodule Billboard.Component.Verifiers.VerifyPlaceholder do
  @moduledoc """
  Checks that every key of the placeholder is one the component's primary
  create accepts, so a new section, which is built through create, never
  starts with a field it can't hold. The message names the fix: add the
  attribute, make it public, or add it to a hand-written create's
  `accept`. Its error is a compile warning, as `VerifyTag`'s
  is.

  A component with no primary create is left to `VerifyActions`.
  """
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    placeholder = Verifier.get_option(dsl_state, [:component], :placeholder) || %{}

    case Ash.Resource.Info.primary_action(dsl_state, :create) do
      nil ->
        :ok

      create ->
        accepted = create.accept ++ Enum.map(create.arguments, & &1.name)

        case Enum.find(Map.keys(placeholder), &(&1 not in accepted)) do
          nil -> :ok
          field -> {:error, error(dsl_state, module, message(dsl_state, module, field))}
        end
    end
  end

  defp message(dsl_state, module, field) do
    case Ash.Resource.Info.attribute(dsl_state, field) do
      nil ->
        "`#{inspect(field)}` is in the placeholder but isn't an attribute of " <>
          "#{inspect(module)}. Add the attribute, or take it out of the placeholder."

      %{public?: false} ->
        "`#{inspect(field)}` is in the placeholder, but #{inspect(module)}'s create doesn't " <>
          "accept it, and a new section is built through create. Make the attribute " <>
          "`public?: true`, or take it out of the placeholder."

      %{public?: true} ->
        "`#{inspect(field)}` is in the placeholder, but #{inspect(module)}'s create doesn't " <>
          "accept it, and a new section is built through create. Add it to the create's " <>
          "`accept`, or take it out of the placeholder."
    end
  end

  defp error(dsl_state, module, message) do
    Spark.Error.DslError.exception(
      module: module,
      path: [:component, :placeholder],
      location: Spark.Dsl.Extension.get_opt_anno(dsl_state, [:component], :placeholder),
      message: message
    )
  end
end
