defmodule Billboard.Test.Render do
  @moduledoc "The library's own tests' name for `Billboard.ComponentCase.Render`."
  defdelegate section(type, attrs \\ %{}, key \\ "s1"), to: Billboard.ComponentCase.Render
  defdelegate visitor(section, ctx \\ %{}), to: Billboard.ComponentCase.Render
  defdelegate open(section, ctx \\ %{}), to: Billboard.ComponentCase.Render
  defdelegate glyph(section), to: Billboard.ComponentCase.Render
end
