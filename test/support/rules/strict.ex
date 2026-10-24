defmodule Billboard.Test.Strict do
  @moduledoc """
  A site rule that finds errors outside a section's own key: one about
  the whole page when it holds a band, and one about each section in a
  Two columns. For `Billboard.ComponentCase`'s placeholder check.
  """
  @behaviour Billboard.Rule

  import Billboard.Rule, only: [error: 2]

  @impl true
  def check(_page, sections, _shared) do
    band =
      if Enum.any?(sections, &(&1.content.type == :band)),
        do: [error(nil, "this page takes no band")],
        else: []

    columns =
      for %{content: %{type: :columns}, children: children} <- sections,
          child <- children,
          do: error(child, "a column takes no details")

    band ++ columns
  end
end
