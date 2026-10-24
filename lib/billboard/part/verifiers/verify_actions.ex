defmodule Billboard.Part.Verifiers.VerifyActions do
  @moduledoc """
  Checks that a site's part has a primary read, create, and update
  action. `use Billboard.Part` adds none, so a part whose `defaults`
  leave one out would compile, then fail the first time the editor
  adds an item or saves one. Its error is a compile warning, as every
  Spark verifier's is.

  A part in a list needs a primary destroy too, which
  `Billboard.Component`'s checks on the component holding it ask for.
  """
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  # Each type, what `defaults` writes for it, and why a part needs it.
  @types [
    read: {"`:read`", "Ash reads every embedded resource through it"},
    create: {"`create: :*`", "a new item is built through it"},
    update: {"`update: :*`", "an edit to an item is saved through it"}
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
             "#{inspect(module)} has no primary #{type} action, and #{reason}. " <>
               "Add #{fix} to its `defaults`."
         )}
      end
    end)
  end
end
