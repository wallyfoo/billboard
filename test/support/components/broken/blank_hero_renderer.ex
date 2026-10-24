defmodule Billboard.Test.Broken.BlankHeroRenderer do
  @moduledoc "Draws nothing for `Billboard.Test.Broken.BlankHero`, and a glyph."
  use Billboard.Renderer

  def render(assigns), do: ~H""

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
