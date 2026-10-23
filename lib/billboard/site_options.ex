defmodule Billboard.SiteOptions do
  @moduledoc """
  The values a site offers in a component's settings, where it offers
  fewer than the component has. This is how a site narrows a stock
  setting without replacing the component, and how it chooses the value a
  new section starts with.

  The site names its offers in its module's `options/0`
  (`Billboard.Site`), by component type, then by field:

      [points: [look: [:cards, :rows], columns: [3, 2], points: 1..3]]

    * **A list** offers those values for a scalar field. Its first is the
      site's default, which a new section takes, as a kind's first surface
      is its default (`Billboard.Surfaces`). The editor still lists the
      values in the component's own order (`options/3`).
    * **A range**, stepping by one, offers lengths for a list field, such
      as a list of parts: `1..3` lets a section hold one to three.
    * A field the site doesn't name offers everything the component
      allows.

  Every component applies the offers itself, through
  `Billboard.Changes.SiteOptions`, which billboard adds to it: a new
  section takes the site's defaults, and a save that changes a field to a
  value the site doesn't offer is refused.

  ## Checks

  Reading an offer checks it against the component, and raises
  `ArgumentError` naming the fix, so a typo in the site's module fails
  where it's read rather than offering nothing, or offering a value no
  section could save:

    * the field must be one of the component's attributes;
    * a list must offer at least one value, each within the attribute's
      `one_of` constraint when it has one, and within its `min` and `max`
      when it's an integer;
    * a range is only for a list attribute, `{:array, _}`, must step by
      one, and must sit within the attribute's `min_length` and
      `max_length`.
  """

  alias Billboard.Site

  @typedoc "What a site offers for one field: everything, some values, or some lengths."
  @type offer :: :all | [term()] | Range.t()

  @doc """
  What the site offers for `type`'s `field`: `:all` when it doesn't name
  the field, or the list or range it names, checked.
  """
  @spec offered(atom(), atom()) :: offer()
  def offered(type, field) when is_atom(type) and is_atom(field) do
    case type |> site_options() |> Keyword.fetch(field) do
      {:ok, offer} -> check_offer!(type, field, offer)
      :error -> :all
    end
  end

  @doc """
  Whether the site offers `value` for `type`'s `field`. For a range,
  `value` is the list, and it's offered when its length is in the range;
  `nil` counts as empty.
  """
  @spec offers?(atom(), atom(), term()) :: boolean()
  def offers?(type, field, value) when is_atom(type) and is_atom(field),
    do: offer_includes?(offered(type, field), value)

  @doc """
  The `{label, value}` options of the select for `type`'s `field` that
  the site offers, in the component's order.
  """
  @spec options(atom(), atom(), [{String.t(), term()}]) :: [{String.t(), term()}]
  def options(type, field, options) when is_atom(type) and is_atom(field) do
    offer = offered(type, field)
    Enum.filter(options, fn {_label, value} -> offer_includes?(offer, value) end)
  end

  @doc """
  The value a new section of `type` takes for `field`: `{:ok, first}` for
  a list offer, and `:error` for a range or a field the site doesn't name,
  where the component's own default stands.
  """
  @spec default(atom(), atom()) :: {:ok, term()} | :error
  def default(type, field) do
    case offered(type, field) do
      [first | _] -> {:ok, first}
      _ -> :error
    end
  end

  @doc """
  The value to draw for `type`'s `field`, given the `value` a section
  records: that one while the site offers it, and the site's default
  otherwise, so a section saved before the site narrowed the field is
  drawn with a value the site still has. A range, or a field the site
  doesn't name, returns `value` as it is.
  """
  @spec resolve(atom(), atom(), term()) :: term()
  def resolve(type, field, value) do
    case offered(type, field) do
      [first | _] = values -> if value in values, do: value, else: first
      _ -> value
    end
  end

  @doc """
  The most items `type`'s list `field` may hold: the range's last when the
  site offers a range, and otherwise the attribute's own `max_length`, or
  `nil` when it has none.
  """
  @spec max_length(atom(), atom()) :: non_neg_integer() | nil
  def max_length(type, field) do
    case offered(type, field) do
      %Range{last: last} -> last
      _ -> Keyword.get(attribute!(type, field).constraints, :max_length)
    end
  end

  @doc """
  Every field the site names for `type`, with its offer, checked, in the
  site's order. It's empty, and looks nothing up, for a type the site
  names no options for.
  """
  @spec narrowed(atom()) :: [{atom(), [term()] | Range.t()}]
  def narrowed(type) when is_atom(type) do
    for {field, offer} <- site_options(type), do: {field, check_offer!(type, field, offer)}
  end

  defp offer_includes?(:all, _value), do: true
  defp offer_includes?(%Range{} = range, value), do: length(value || []) in range
  defp offer_includes?(values, value), do: value in values

  defp site_options(type), do: Keyword.get(Site.get!().options(), type, [])

  # An offer names a real field and offers only what the field allows.
  # Each mistake raises where the offer is read, so it fails loudly rather
  # than offering nothing, or offering a value no section could save.
  defp check_offer!(type, field, offer) do
    attribute = attribute!(type, field)

    case offer do
      %Range{} -> check_range!(type, field, attribute, offer)
      [_ | _] -> check_values!(type, field, attribute, offer)
      [] -> raise ArgumentError, empty_message(type, field)
      _ -> raise ArgumentError, shape_message(type, field, offer)
    end

    offer
  end

  defp check_values!(type, field, attribute, values) do
    allowed = Keyword.get(attribute.constraints, :one_of)

    case allowed && Enum.reject(values, &(&1 in allowed)) do
      [unknown | _] ->
        raise ArgumentError,
              "the site offers #{inspect(type)}'s #{inspect(field)} #{inspect(unknown)}, " <>
                "which isn't one of its options, #{inspect(allowed)}. Take it out of the " <>
                "site's options/0"

      _ ->
        :ok
    end

    if attribute.type == Ash.Type.Integer, do: check_bounds!(type, field, attribute, values)
  end

  defp check_bounds!(type, field, attribute, values) do
    min = Keyword.get(attribute.constraints, :min)
    max = Keyword.get(attribute.constraints, :max)

    case Enum.find(values, &(not is_integer(&1) or below?(&1, min) or above?(&1, max))) do
      nil ->
        :ok

      outside ->
        raise ArgumentError,
              "the site offers #{inspect(type)}'s #{inspect(field)} #{inspect(outside)}, " <>
                "which is outside what it allows, #{bounds(min, max)}. Take it out of the " <>
                "site's options/0"
    end
  end

  defp check_range!(type, field, attribute, range) do
    unless match?({:array, _}, attribute.type) do
      raise ArgumentError,
            "the site offers #{inspect(type)}'s #{inspect(field)} the range #{inspect(range)}, " <>
              "but a range offers a list's lengths, and #{inspect(field)} isn't a list. " <>
              "Offer a list of its values instead"
    end

    if range.step != 1 or range.first > range.last do
      raise ArgumentError,
            "the site offers #{inspect(type)}'s #{inspect(field)} the range #{inspect(range)}, " <>
              "which doesn't count up by one. Write it as first..last, such as 1..3"
    end

    min = Keyword.get(attribute.constraints, :min_length, 0)
    max = Keyword.get(attribute.constraints, :max_length)

    if range.first < min or above?(range.last, max) do
      raise ArgumentError,
            "the site offers #{inspect(type)}'s #{inspect(field)} #{inspect(range)}, " <>
              "which is outside the lengths it allows, #{bounds(min, max)}. Narrow the range " <>
              "in the site's options/0"
    end
  end

  defp attribute!(type, field) do
    module = Site.component!(type)

    Ash.Resource.Info.attribute(module, field) ||
      raise ArgumentError,
            "the site offers values for #{inspect(type)}'s #{inspect(field)}, " <>
              "which isn't one of its fields. Take it out of the site's options/0, " <>
              "or name one of #{inspect(public_fields(module))}"
  end

  defp public_fields(module) do
    module
    |> Ash.Resource.Info.public_attributes()
    |> Enum.map(& &1.name)
    |> Enum.reject(&(&1 == :component))
  end

  defp empty_message(type, field) do
    "the site offers nothing for #{inspect(type)}'s #{inspect(field)}. Offer at least " <>
      "one value, or take the field out of the site's options/0 to offer every value"
  end

  defp shape_message(type, field, offer) do
    "the site's offer for #{inspect(type)}'s #{inspect(field)}, #{inspect(offer)}, " <>
      "isn't a list or a range. Offer a list of values, or a range of lengths for a list"
  end

  defp below?(value, min), do: is_integer(min) and value < min
  defp above?(value, max), do: is_integer(max) and value > max

  defp bounds(nil, nil), do: "any number"
  defp bounds(min, nil), do: "at least #{min}"
  defp bounds(nil, max), do: "at most #{max}"
  defp bounds(min, max), do: "#{min} to #{max}"
end
