defmodule Billboard.Sections.Voronoi do
  @moduledoc """
  Voronoi noise for empty photograph slots. Sites are scattered from a seed,
  so a slot always draws the same pattern and the server and connected renders
  agree. Each cell is a 100 × 100 box clipped by the perpendicular bisector
  against every other site, and takes one of the nine noise tokens,
  `--bb-noise-1` to `--bb-noise-9`, which the site sets to its own colours.
  `Billboard.Sections.Blocks.voronoi_noise/1` draws it, and a site may too.
  """

  @palette ~w(noise-1 noise-2 noise-3 noise-4 noise-5 noise-6 noise-7 noise-8 noise-9)
  @size 100

  @doc """
  Returns `count` cells for `seed`, each with an SVG `points` string and the
  noise token it is filled with, without its `--bb-` prefix: `"noise-3"`
  for `--bb-noise-3`.
  """
  def cells(seed, count \\ 24) when is_integer(count) and count > 0 do
    state = :rand.seed_s(:exsss, :erlang.phash2(seed))

    {sites, state} =
      Enum.map_reduce(1..count, state, fn _, state ->
        {x, state} = :rand.uniform_s(state)
        {y, state} = :rand.uniform_s(state)
        {{x * @size, y * @size}, state}
      end)

    {colours, _state} =
      Enum.map_reduce(sites, state, fn _, state ->
        {i, state} = :rand.uniform_s(length(@palette), state)
        {Enum.at(@palette, i - 1), state}
      end)

    box = [{0.0, 0.0}, {@size * 1.0, 0.0}, {@size * 1.0, @size * 1.0}, {0.0, @size * 1.0}]

    Enum.zip_with(sites, colours, fn site, colour ->
      polygon =
        Enum.reduce(sites, box, fn
          ^site, polygon -> polygon
          other, polygon -> clip(polygon, site, other)
        end)

      %{points: points(polygon), colour: colour}
    end)
  end

  @doc "The side of the square the cells fill, for the SVG viewBox."
  def size, do: @size

  # Sutherland–Hodgman against one half-plane: keep what is nearer site a than site b.
  defp clip([], _a, _b), do: []

  defp clip(polygon, {ax, ay}, {bx, by}) do
    {nx, ny} = {bx - ax, by - ay}
    {mx, my} = {(ax + bx) / 2, (ay + by) / 2}
    side = fn {px, py} -> (px - mx) * nx + (py - my) * ny end

    polygon
    |> Enum.zip(tl(polygon) ++ [hd(polygon)])
    |> Enum.flat_map(fn {p, q} ->
      {sp, sq} = {side.(p), side.(q)}

      cond do
        sp <= 0 and sq <= 0 -> [q]
        sp <= 0 -> [intersect(p, q, sp, sq)]
        sq <= 0 -> [intersect(p, q, sp, sq), q]
        true -> []
      end
    end)
  end

  defp intersect({px, py}, {qx, qy}, sp, sq) do
    t = sp / (sp - sq)
    {px + t * (qx - px), py + t * (qy - py)}
  end

  defp points(polygon) do
    Enum.map_join(polygon, " ", fn {x, y} ->
      "#{:erlang.float_to_binary(x, decimals: 2)},#{:erlang.float_to_binary(y, decimals: 2)}"
    end)
  end
end
