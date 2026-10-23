defmodule Billboard.Component.Verifiers.VerifyRenderer do
  @moduledoc """
  Checks that a component's `renderer`, when it names one, is a module.
  It looks once the component has compiled, so naming the renderer still
  makes no compile-time dependency. Its errors are compile warnings, as
  every Spark verifier's are.
  """
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    renderer = Verifier.get_option(dsl_state, [:component], :renderer)

    if is_nil(renderer) or match?({:module, _}, Code.ensure_compiled(renderer)) do
      :ok
    else
      {:error,
       Spark.Error.DslError.exception(
         module: module,
         path: [:component, :renderer],
         message:
           "`renderer` names #{inspect(renderer)}, which isn't a module. Define it, with " <>
             "`use Billboard.Renderer`, or name the module that draws #{inspect(module)}"
       )}
    end
  end
end
