defmodule Billboard.Parts.PointTest do
  @moduledoc "One of a row of points. Built in memory, as a component's content would be."
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Parts.{Action, Point}

  setup do: put_site!(actions: Billboard.Test.Actions, example_path: "/the-salon")

  defp part!(attrs), do: Point |> Ash.Changeset.for_create(:create, attrs) |> Ash.create!()

  test "needs a title, and has its own id" do
    assert %Point{title: "Quiet", id: id} = part!(%{title: "Quiet"})
    assert is_binary(id)

    assert_raise Ash.Error.Invalid, fn -> part!(%{body: "No title."}) end
  end

  test "links only to a page on this site" do
    assert %Point{link: %Action{kind: :link}} =
             part!(%{title: "Quiet", link: %{label: "The salon", path: "/the-salon"}})

    assert_raise Ash.Error.Invalid, ~r/a point links to a page on this site/, fn ->
      part!(%{title: "Quiet", link: %{kind: :visit}})
    end
  end
end
