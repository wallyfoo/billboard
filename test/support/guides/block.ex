defmodule Billboard.Test.Guides.Block do
  @moduledoc """
  One fenced block of a guide: its language, its text, its marker (`:from`,
  `:site`, `:run`, `:fails`, `:sketch`, or nil) and the marker's argument,
  and the guide and line it opens on.
  """
  defstruct [:guide, :line, :lang, :text, :marker, :arg]
end
