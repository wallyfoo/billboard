defmodule Billboard.Parts.PointTest do
  @moduledoc "One of a row of points. Built in memory, as a component's content would be."
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Ash.Error.Changes.InvalidAttribute
  alias Billboard.Parts.{Action, Point}

  setup do
    put_site!(
      components: [Billboard.Components.Points],
      actions: Billboard.Test.Actions,
      offered: [page: ["plain"], stand_out: ["loud"], card: ["plain"]]
    )
  end

  defp part!(attrs), do: Point |> Ash.Changeset.for_create(:create, attrs) |> Ash.create!()

  test "needs a title, and has its own id" do
    assert %Point{title: "Quiet", id: id} = part!(%{title: "Quiet"})
    assert is_binary(id)

    assert_raise Ash.Error.Invalid, fn -> part!(%{body: "No title."}) end
  end

  test "links only to a page on this site" do
    assert %Point{link: %Action{kind: :link}} =
             part!(%{title: "Quiet", link: %{label: "About", path: "/about"}})

    assert_raise Ash.Error.Invalid, ~r/a point links to a page on this site/, fn ->
      part!(%{title: "Quiet", link: %{kind: :visit}})
    end
  end

  test "is refused as invalid in a section's list, as it is alone" do
    assert %InvalidAttribute{field: :link} =
             error_in_list([%{title: "Quiet", link: %{kind: :visit}}], "a point links")

    assert %InvalidAttribute{field: :surface} =
             error_in_list([%{title: "Quiet", surface: "loud"}], "“loud” isn't a surface")
  end

  # The error, among a points section's errors, whose message has
  # `words`. A list's items are cast together, through Ash's bulk create.
  defp error_in_list(points, words) do
    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Billboard.Component.build(:points, %{points: points})

    Enum.find(errors, &(Exception.message(&1) =~ words))
  end
end
