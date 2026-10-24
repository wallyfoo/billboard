defmodule Billboard.Test.OwnHeroRenderer do
  @moduledoc """
  Draws `Billboard.Test.OwnHero`: its heading, in a block of its own,
  where the stock hero draws its grid.
  """
  use Billboard.Renderer

  def render(assigns) do
    ~H"""
    <div id="own-hero">
      <h1>{Words.text(@ctx, "heading", @content.heading)}</h1>
    </div>
    """
  end

  def glyph(assigns), do: ~H|<Glyph.bars class="flex-1" />|
end
