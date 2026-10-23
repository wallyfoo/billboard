defmodule Billboard.Component.Transformers.AddActions do
  @moduledoc """
  Gives the component the actions every component has,
  `defaults [:read, :destroy, create: :*, update: :*]`, less any the
  component writes itself by those names. A component that writes its own
  `defaults` keeps them as written.

  It works by setting the `actions` section's `defaults` option, so Ash
  builds the actions exactly as it does for `defaults` written by hand:
  each is primary unless the component has another primary action of its
  type, and update and destroy follow the site's
  `config :ash, default_actions_require_atomic?`.

  Ash 3.33 already does the same for an embedded resource that writes no
  `defaults`, but it doesn't document it. This makes the rule billboard's
  own, so it holds whatever Ash does.

  It runs after `AddTag` and `AddParts`, and before every Ash resource
  transformer, so Ash's `SetPrimaryActions` builds the actions, and
  `DefaultAccept`, which runs after it, expands `:*` to every public
  attribute, the tag and the parts included.

  A component that writes its own `defaults` may leave a type out;
  `Billboard.Component.Verifiers.VerifyActions` says so.
  """
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  @defaults [:read, :destroy, create: :*, update: :*]

  @impl true
  def after?(Billboard.Component.Transformers.AddTag), do: true
  def after?(Billboard.Component.Transformers.AddParts), do: true
  def after?(_), do: false

  @impl true
  def before?(transformer), do: transformer in Ash.Resource.Dsl.transformers()

  @impl true
  def transform(dsl_state) do
    if Transformer.get_option(dsl_state, [:actions], :defaults) do
      {:ok, dsl_state}
    else
      written = dsl_state |> Transformer.get_entities([:actions]) |> MapSet.new(& &1.name)

      defaults =
        Enum.reject(@defaults, fn
          {name, _accept} -> name in written
          name -> name in written
        end)

      {:ok, Transformer.set_option(dsl_state, [:actions], :defaults, defaults)}
    end
  end
end
