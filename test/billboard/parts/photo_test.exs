defmodule Billboard.Parts.PhotoTest do
  @moduledoc "A photograph, or its placeholder. Built in memory, as a component's content would be."
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Parts.Photo

  setup do: put_site!(actions: Billboard.Test.Actions, example_path: "/the-salon")

  defp part!(attrs), do: Photo |> Ash.Changeset.for_create(:create, attrs) |> Ash.create!()

  test "says what it shows, and only points at an upload" do
    assert %Photo{label: "The room"} = part!(%{label: "The room"})

    assert_raise Ash.Error.Invalid, ~r/upload a photograph here/, fn ->
      part!(%{label: "x", path: "https://example.com/a.jpg", alt: "A room"})
    end
  end

  test "with an upload, describes it for people who can't see it" do
    assert %Photo{path: "/uploads/room.jpg"} =
             part!(%{label: "x", path: "/uploads/room.jpg", alt: "The salon floor"})

    assert_raise Ash.Error.Invalid, ~r/describe the photograph/, fn ->
      part!(%{label: "x", path: "/uploads/room.jpg"})
    end
  end

  test "needs a label" do
    assert_raise Ash.Error.Invalid, fn -> part!(%{alt: "A room"}) end
  end
end
