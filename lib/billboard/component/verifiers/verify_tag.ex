defmodule Billboard.Component.Verifiers.VerifyTag do
  @moduledoc """
  Checks a `component` attribute the component writes itself. It must be
  `one_of: [key]`, or Ash would store a section under one type and read
  it back as another.

  Like every Spark verifier, it runs once the module has compiled, and
  its error is printed as a compile warning rather than raised, so
  `mix compile --warnings-as-errors` fails on it.
  """
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    key = Verifier.get_option(dsl_state, [:component], :key)
    module = Verifier.get_persisted(dsl_state, :module)

    case Ash.Resource.Info.attribute(dsl_state, :component) do
      %{constraints: constraints} = attribute ->
        if Keyword.get(constraints, :one_of) == [key] do
          :ok
        else
          {:error,
           Spark.Error.DslError.exception(
             module: module,
             path: [:attributes, :component],
             location: Spark.Dsl.Entity.anno(attribute),
             message:
               "#{inspect(module)}'s `component` attribute must be " <>
                 "`one_of: [#{inspect(key)}]`. Take it out; billboard adds it."
           )}
        end

      nil ->
        :ok
    end
  end
end
