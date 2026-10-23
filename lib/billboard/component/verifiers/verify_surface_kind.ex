defmodule Billboard.Component.Verifiers.VerifySurfaceKind do
  @moduledoc """
  Refuses `surface_kind :card`. `:card` is the kind of a card inside a
  section (`Billboard.Surfaces.card/1`), which a site may offer no
  surfaces at all, since a card that names none is drawn on its section's.
  A section always needs a ground of its own, so a component of that kind
  could never be drawn: `Billboard.Surfaces.default(:card)` raises. The
  message names the kinds to use instead. Its error is a compile warning,
  as `VerifyTag`'s is.
  """
  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    case Verifier.get_option(dsl_state, [:component], :surface_kind) do
      :card ->
        module = Verifier.get_persisted(dsl_state, :module)

        {:error,
         Spark.Error.DslError.exception(
           module: module,
           path: [:component, :surface_kind],
           location: Spark.Dsl.Extension.get_opt_anno(dsl_state, [:component], :surface_kind),
           message:
             "#{inspect(module)}'s `surface_kind` is `:card`, but `:card` is the kind of a " <>
               "card inside a section, not of a section, and a section needs a ground of its " <>
               "own. Use `:page`, `:stand_out`, or another kind the site offers its sections."
         )}

      _kind ->
        :ok
    end
  end
end
