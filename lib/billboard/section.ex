defmodule Billboard.Section do
  @moduledoc "One component placed on a version. `use Billboard.Section` comes with the resources."

  @doc """
  The section's DOM id on the public page: its anchor, or one made from
  its key.
  """
  @spec dom_id(%{anchor: String.t() | nil, key: String.t()}) :: String.t()
  def dom_id(%{anchor: anchor}) when is_binary(anchor), do: anchor
  def dom_id(%{key: key}), do: "section-#{key}"
end
