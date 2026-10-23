defmodule Billboard.Sections.VoronoiTest do
  @moduledoc "The noise an empty photograph slot draws: the same for a seed, and tiling its box."
  use ExUnit.Case, async: true

  alias Billboard.Sections.Voronoi

  @palette ~w(noise-1 noise-2 noise-3 noise-4 noise-5 noise-6 noise-7 noise-8 noise-9)

  test "the same seed draws the same cells" do
    assert Voronoi.cells("The shopfront") == Voronoi.cells("The shopfront")
    refute Voronoi.cells("The shopfront") == Voronoi.cells("Colour at the basin")
  end

  test "draws one cell per site, in the noise colours, inside the box" do
    cells = Voronoi.cells("The shopfront", 24)

    assert length(cells) == 24

    for %{points: points, colour: colour} <- cells do
      assert colour in @palette

      for pair <- String.split(points, " "), coord <- String.split(pair, ",") do
        {value, ""} = Float.parse(coord)
        assert value >= 0 and value <= Voronoi.size()
      end
    end
  end

  test "the cells tile the box" do
    area =
      "The shopfront"
      |> Voronoi.cells(24)
      |> Enum.map(fn %{points: points} ->
        vertices =
          for pair <- String.split(points, " ") do
            [x, y] = pair |> String.split(",") |> Enum.map(&String.to_float/1)
            {x, y}
          end

        vertices
        |> Enum.zip(tl(vertices) ++ [hd(vertices)])
        |> Enum.reduce(0, fn {{x1, y1}, {x2, y2}}, acc -> acc + x1 * y2 - x2 * y1 end)
        |> abs()
        |> Kernel./(2)
      end)
      |> Enum.sum()

    assert_in_delta area, Voronoi.size() * Voronoi.size(), 1
  end
end
