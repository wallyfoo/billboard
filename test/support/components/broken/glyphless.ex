defmodule Billboard.Test.Broken.Glyphless do
  @moduledoc "A component whose glyph draws nothing, for `Billboard.ComponentCase`."
  use Billboard.Component

  component do
    key :glyphless
    label "Glyphless"
    hint "A glyph that draws nothing."
    category :content
    renderer Billboard.Test.Broken.GlyphlessRenderer
    placeholder %{title: "Your title"}
  end

  attributes do
    attribute :title, :string, public?: true
  end
end
