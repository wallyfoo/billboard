defmodule Billboard.Component.Transformers.AddTag do
  @moduledoc """
  Adds the union tag, the `component` attribute, unless the component
  writes its own (`Billboard.Component.Verifiers.VerifyTag` checks one
  that does):

      attribute :component, :atom,
        allow_nil?: false, default: key, public?: true, constraints: [one_of: [key]]

  The tag goes first among the attributes, where hand-written components
  put it. It runs before every Ash resource transformer, as if it were
  written in the module, so Ash's `DefaultAccept` sees it when it expands
  `accept: :*`.

  A module with no `component` section fails to compile here: Spark
  checks a section's required options only when the section is written.
  """
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  @impl true
  def before?(transformer), do: transformer in Ash.Resource.Dsl.transformers()

  @impl true
  def transform(dsl_state) do
    key = Transformer.get_option(dsl_state, [:component], :key)

    cond do
      is_nil(key) ->
        module = Transformer.get_persisted(dsl_state, :module)

        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: [:component],
           message:
             "#{inspect(module)} has no `component` section. Add one with its " <>
               "`key`, `label`, `hint`, and `category`."
         )}

      Ash.Resource.Info.attribute(dsl_state, :component) ->
        {:ok, dsl_state}

      true ->
        add_tag(dsl_state, key)
    end
  end

  defp add_tag(dsl_state, key) do
    with {:ok, tag} <-
           Ash.Resource.Builder.build_attribute(:component, :atom,
             allow_nil?: false,
             default: key,
             public?: true,
             constraints: [one_of: [key]]
           ) do
      # First, where every component writes it today, so the attributes
      # and the actions' accept lists come out in the same order.
      {:ok, Transformer.add_entity(dsl_state, [:attributes], tag, type: :prepend)}
    end
  end
end
