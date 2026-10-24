defmodule Billboard.Test.Guides.Block do
  @moduledoc """
  One fenced block of a guide: its language, its text, its marker (`:from`,
  `:site`, `:run`, `:fails`, `:sketch`, or nil) and the marker's argument,
  and the guide and line it opens on. `fence` is how it's drawn: "```",
  the only fence the guides use, or another the check refuses (`"~~~"`,
  a longer run of backticks, or `:indented`, four spaces in).
  """
  defstruct [:guide, :line, :lang, :text, :marker, :arg, fence: "```"]
end
