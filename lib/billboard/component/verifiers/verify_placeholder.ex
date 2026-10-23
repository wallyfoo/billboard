defmodule Billboard.Component.Verifiers.VerifyPlaceholder do
  @moduledoc """
  Checks that every key of the placeholder names one of the component's
  attributes, so a new section never starts with a field it can't hold.
  Its error is a compile warning, as `VerifyTag`'s is.
  """
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    placeholder = Verifier.get_option(dsl_state, [:component], :placeholder) || %{}

    case Enum.find(Map.keys(placeholder), &is_nil(Ash.Resource.Info.attribute(dsl_state, &1))) do
      nil ->
        :ok

      field ->
        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: [:component, :placeholder],
           location: Spark.Dsl.Extension.get_opt_anno(dsl_state, [:component], :placeholder),
           message:
             "`#{inspect(field)}` is in the placeholder but isn't an attribute of " <>
               "#{inspect(module)}. Add the attribute, or take it out of the placeholder."
         )}
    end
  end
end
