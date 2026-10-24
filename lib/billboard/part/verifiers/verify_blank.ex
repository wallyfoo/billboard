defmodule Billboard.Part.Verifiers.VerifyBlank do
  @moduledoc """
  Checks that every top-level key of a site part's blank is one the
  part's primary create accepts, so a new item, which is built through
  create, never starts with a field it can't hold. The message names the
  fix: add the attribute, make it public, or add it to a hand-written
  create's `accept`. Its error is a compile warning, as every Spark
  verifier's is.

  It checks the top-level keys only: what a nested part's map holds is
  left to that part's create, when a new item is built. A part with no
  primary create is left to `Billboard.Part.Verifiers.VerifyActions`,
  which refuses it.
  """
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    blank = Verifier.get_option(dsl_state, [:part], :blank) || %{}

    case Ash.Resource.Info.primary_action(dsl_state, :create) do
      nil ->
        :ok

      create ->
        accepted = create.accept ++ Enum.map(create.arguments, & &1.name)

        case Enum.find(Map.keys(blank), &(&1 not in accepted)) do
          nil -> :ok
          field -> {:error, error(dsl_state, module, message(dsl_state, module, field))}
        end
    end
  end

  defp message(dsl_state, module, field) do
    case Ash.Resource.Info.attribute(dsl_state, field) do
      nil ->
        "`#{inspect(field)}` is in the blank but isn't an attribute of " <>
          "#{inspect(module)}. Add the attribute, or take it out of the blank."

      %{public?: false} ->
        "`#{inspect(field)}` is in the blank, but #{inspect(module)}'s create doesn't " <>
          "accept it, and a new item is built through create. Make the attribute " <>
          "`public?: true`, or take it out of the blank."

      %{public?: true} ->
        "`#{inspect(field)}` is in the blank, but #{inspect(module)}'s create doesn't " <>
          "accept it, and a new item is built through create. Add it to the create's " <>
          "`accept`, or take it out of the blank."
    end
  end

  defp error(dsl_state, module, message) do
    Spark.Error.DslError.exception(
      module: module,
      path: [:part, :blank],
      location: Spark.Dsl.Extension.get_opt_anno(dsl_state, [:part], :blank),
      message: message
    )
  end
end
