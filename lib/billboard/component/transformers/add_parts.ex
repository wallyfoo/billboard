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

  A part named like an attribute the component writes, like the tag
  (`:component`), or like another part doesn't compile, rather than
  leaving the part silently unused, and nor does a `parts` whose `min` is
  above its `max`. Each error names the fix.
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
    module = Transformer.get_persisted(dsl_state, :module)

    dsl_state
    |> Transformer.get_entities([:component])
    |> Enum.reduce_while({:ok, dsl_state}, fn part, {:ok, dsl_state} ->
      with :ok <- check(dsl_state, module, part),
           {type, opts} = attribute(part),
           {:ok, dsl_state} <-
             Ash.Resource.Builder.add_attribute(dsl_state, part.name, type, opts) do
        {:cont, {:ok, dsl_state}}
      else
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  # Each part runs after the ones before it, so an attribute of its name is
  # the component's own, the tag, or an earlier part's.
  defp check(dsl_state, module, part) do
    cond do
      part.name == :component ->
        error(
          module,
          part,
          "`:component` is the tag billboard adds to every component, " <>
            "so a part can't take its name. Rename the part."
        )

      Ash.Resource.Info.attribute(dsl_state, part.name) && earlier_part?(dsl_state, part) ->
        error(
          module,
          part,
          "#{inspect(module)} has two parts named `#{inspect(part.name)}`. " <>
            "Rename one of them."
        )

      Ash.Resource.Info.attribute(dsl_state, part.name) ->
        error(
          module,
          part,
          "`#{inspect(part.name)}` is both a part and an attribute of " <>
            "#{inspect(module)}. Rename the part, or take the attribute out."
        )

      min_above_max?(part) ->
        error(
          module,
          part,
          "`parts #{inspect(part.name)}` has `min: #{part.min}` above " <>
            "`max: #{part.max}`, so no list could hold it. Make `min` at most `max`."
        )

      true ->
        :ok
    end
  end

  defp min_above_max?(%Parts{min: min, max: max}) when is_integer(min) and is_integer(max),
    do: min > max

  defp min_above_max?(_part), do: false

  defp earlier_part?(dsl_state, part) do
    dsl_state
    |> Transformer.get_entities([:component])
    |> Enum.take_while(&(&1 != part))
    |> Enum.any?(&(&1.name == part.name))
  end

  defp error(module, part, message) do
    {:error,
     Spark.Error.DslError.exception(
       module: module,
       path: [:component, part.name],
       location: Spark.Dsl.Entity.anno(part),
       message: message
     )}
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
