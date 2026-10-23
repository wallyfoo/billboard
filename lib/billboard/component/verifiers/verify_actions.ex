defmodule Billboard.Component.Verifiers.VerifyActions do
  @moduledoc """
  Checks that the component has a primary read, create, update, and
  destroy action. Billboard adds all four unless the component writes its
  own `defaults`, which are kept as written, so one that leaves a type out
  would otherwise compile, then fail the first time a section needs it.

  Its error is a compile warning, as every Spark verifier's is.
  """
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  # Each type, what `defaults` writes for it, and why a component needs it.
  @types [
    read: {"`:read`", "Ash reads every embedded resource through it"},
    create: {"`create: :*`", "Ash builds a new section's component through it"},
    update: {"`update: :*`", "Ash saves an edit to a section's component through it"},
    destroy: {"`:destroy`", "Ash destroys a section's component when it's replaced"}
  ]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)

    Enum.find_value(@types, :ok, fn {type, {fix, reason}} ->
      if is_nil(Ash.Resource.Info.primary_action(dsl_state, type)) do
        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: [:actions, :defaults],
           location: Spark.Dsl.Extension.get_opt_anno(dsl_state, [:actions], :defaults),
           message:
             "#{inspect(module)} has no primary #{type} action, and #{reason}. Add #{fix} " <>
               "to its `defaults`, or take `defaults` out; billboard adds them."
         )}
      end
    end)
  end
end
