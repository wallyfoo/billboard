defmodule Billboard.Component.Transformers.AddParts do
  @moduledoc """
  Turns each `part` and `parts` into the attribute that holds it, after
  the component's own attributes:

      part :head, MySite.Parts.Head
      # attribute :head, MySite.Parts.Head, public?: true, allow_nil?: true

      parts :points, MySite.Parts.Point, min: 1, max: 3
      # attribute :points, {:array, MySite.Parts.Point},
      #   public?: true, allow_nil?: false, default: [],
      #   constraints: [min_length: 1, max_length: 3]

  `min_length` and `max_length` are set only when `min` and `max` are
  given, and `description` only when it is.

  It runs after `AddTag` and before `AddActions` and every Ash resource
  transformer, so `accept: :*` takes the parts in.

  It adds each attribute with `add_attribute/4`, not `add_new_attribute/4`,
  so a part named like an attribute the component writes doesn't compile
  (Ash refuses two attributes of one name), rather than leaving the part
  silently unused.
  """
  use Spark.Dsl.Transformer

  alias Billboard.Component.{Part, Parts}
  alias Spark.Dsl.Transformer

  @impl true
  def after?(Billboard.Component.Transformers.AddTag), do: true
  def after?(_), do: false

  @impl true
  def before?(Billboard.Component.Transformers.AddActions), do: true
  def before?(transformer), do: transformer in Ash.Resource.Dsl.transformers()

  @impl true
  def transform(dsl_state) do
    dsl_state
    |> Transformer.get_entities([:component])
    |> Enum.reduce_while({:ok, dsl_state}, fn part, {:ok, dsl_state} ->
      {type, opts} = attribute(part)

      case Ash.Resource.Builder.add_attribute(dsl_state, part.name, type, opts) do
        {:ok, dsl_state} -> {:cont, {:ok, dsl_state}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp attribute(%Part{} = part) do
    {part.type,
     [public?: true, allow_nil?: part.allow_nil?] |> put_given(:description, part.description)}
  end

  defp attribute(%Parts{} = parts) do
    constraints =
      []
      |> put_given(:min_length, parts.min)
      |> put_given(:max_length, parts.max)

    opts =
      [public?: true, allow_nil?: parts.allow_nil?, default: []]
      |> put_given(:constraints, if(constraints != [], do: constraints))
      |> put_given(:description, parts.description)

    {{:array, parts.type}, opts}
  end

  defp put_given(opts, _key, nil), do: opts
  defp put_given(opts, key, value), do: opts ++ [{key, value}]
end
