defmodule Billboard.Component.Verifiers.VerifyTag do
  @moduledoc """
  Checks a `component` attribute the component writes itself against the
  one `AddTag` would add:

      attribute :component, :atom,
        allow_nil?: false, default: key, public?: true, constraints: [one_of: [key]]

  Its type, `allow_nil?`, `default`, `public?`, and `one_of` must all
  match. Without `one_of: [key]`, Ash would store a section under one type
  and read it back as another; without the rest, a section could be saved
  untagged, or the tag left out of the actions' `accept`. The message names
  each setting that differs.

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
      nil ->
        :ok

      attribute ->
        case differences(attribute, key) do
          [] ->
            :ok

          differences ->
            {:error,
             Spark.Error.DslError.exception(
               module: module,
               path: [:attributes, :component],
               location: Spark.Dsl.Entity.anno(attribute),
               message:
                 "#{inspect(module)}'s `component` attribute must be " <>
                   "`#{Enum.join(differences, ", ")}`. Take it out; billboard adds it."
             )}
        end
    end
  end

  # What `AddTag` sets, in the order it writes it, less what matches.
  defp differences(attribute, key) do
    [
      {attribute.type == Ash.Type.Atom, ":atom"},
      {attribute.allow_nil? == false, "allow_nil?: false"},
      {attribute.default == key, "default: #{inspect(key)}"},
      {attribute.public? == true, "public?: true"},
      {Keyword.get(attribute.constraints, :one_of) == [key],
       "constraints: [one_of: [#{inspect(key)}]]"}
    ]
    |> Enum.reject(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end
end
