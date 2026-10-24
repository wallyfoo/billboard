defmodule Billboard.Test.GroundRule do
  @moduledoc """
  A site rule for `Billboard.RulesTest`, written as a site with two
  stand-out surfaces might: two stand-out sections in a row, drawn on the
  same surface, are an error. A test adds it through
  `put_shop!(rules: [Billboard.Test.GroundRule])`.

  It compares the surface each section is drawn on, so a `nil` surface,
  or one the site has stopped offering, counts as its kind's default. A
  Shared section is drawn as its library section, with that section's
  type and surface.
  """
  @behaviour Billboard.Rule

  alias Billboard.Rules
  alias Billboard.Surfaces

  @impl true
  @doc "An error for each stand-out section on the same ground as the one before it."
  def check(_page, sections, shared) do
    sections
    |> Enum.map(&{&1, ground(&1, shared)})
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn
      [{_, {:stand_out, surface}}, {section, {:stand_out, surface}}] ->
        [Billboard.Rule.error(section, "two stand-out sections in a row can't share a ground")]

      _ ->
        []
    end)
  end

  # The kind and surface of what `section` draws.
  defp ground(section, shared) do
    type = Rules.effective_type(section, shared)
    surface = drawn(section, shared).surface
    {Surfaces.kind(type), Surfaces.resolve(type, surface)}
  end

  defp drawn(%{content: %Ash.Union{type: :shared, value: %{key: key}}} = section, shared),
    do: Map.get(shared, key, section)

  defp drawn(section, _shared), do: section
end
