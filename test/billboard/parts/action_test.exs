defmodule Billboard.Parts.ActionTest do
  @moduledoc """
  An action: a link to a page on the site, or one of the site's own
  kinds. Built in memory, as a component's content would be.
  """
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Ash.Error.Changes.InvalidAttribute
  alias Billboard.Parts.Action

  setup do: put_site!(components: [Billboard.Components.Hero], actions: Billboard.Test.Actions)

  defp create(attrs), do: Action |> Ash.Changeset.for_create(:create, attrs) |> Ash.create()

  defp create!(attrs), do: Action |> Ash.Changeset.for_create(:create, attrs) |> Ash.create!()

  defp hero(attrs), do: Billboard.Component.build!(:hero, Map.put(attrs, :heading, "Hi"))

  defp update(action, attrs),
    do: action |> Ash.Changeset.for_update(:update, attrs) |> Ash.update()

  test "defaults to a secondary link, and needs a path on this site" do
    assert %Action{kind: :link, style: :secondary} =
             create!(%{label: "Prices", path: "/price-list"})

    assert_raise Ash.Error.Invalid, ~r/starting with \/, such as \/about/, fn ->
      create!(%{label: "Fresha", path: "https://fresha.com"})
    end
  end

  test "a protocol-relative address isn't on this site" do
    assert_raise Ash.Error.Invalid, ~r/starting with \//, fn ->
      create!(%{label: "Fresha", path: "//fresha.com/a"})
    end

    assert %Action{path: "/"} = create!(%{label: "Home", path: "/"})

    assert %Action{path: "/academy#courses"} =
             create!(%{label: "Courses", path: "/academy#courses"})
  end

  test "a link needs a label and an address" do
    assert_raise Ash.Error.Invalid, ~r/a link needs a label and an address/, fn ->
      create!(%{label: "Prices"})
    end
  end

  test "a visit or call action needs no path or label" do
    assert %Action{kind: :visit, style: :primary} = create!(%{kind: :visit, style: :primary})
    assert %Action{kind: :call} = create!(%{kind: :call})
  end

  test "each action in a list has its own id" do
    %{actions: [first, second]} = hero(%{actions: [%{kind: :visit}, %{kind: :call}]})

    assert is_binary(first.id)
    refute first.id == second.id
  end

  test "a hero takes three actions at most" do
    assert_raise Ash.Error.Invalid, fn ->
      hero(%{actions: List.duplicate(%{kind: :visit}, 4)})
    end
  end

  test "takes only the kinds the site offers, checked when the kind changes" do
    assert {:error, error} = create(%{kind: :fly, label: "Away", path: "/"})
    assert Exception.message(error) =~ "this site doesn't offer “fly” here"

    {:ok, visit} = create(%{kind: :visit})
    put_site!(actions: nil)

    assert {:ok, %{kind: :visit, label: "Visit us"}} = update(visit, %{label: "Visit us"})
    assert {:error, _} = update(visit, %{kind: :call})
  end

  test "is refused as invalid in a section's list, as it is alone" do
    for {action, field, words} <- [
          {%{label: "Out", path: "https://elsewhere"}, :path, "starting with /, such as /about"},
          {%{kind: :fly}, :kind, "this site doesn't offer “fly” here"}
        ] do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               Billboard.Component.build(:hero, %{heading: "Hi", actions: [action]})

      assert %InvalidAttribute{field: ^field} = error
      assert Exception.message(error) =~ words
    end
  end

  test "names the site's example path when an address isn't on the site" do
    put_site!(example_path: "/terms")
    assert {:error, error} = create(%{kind: :link, label: "Out", path: "https://elsewhere"})
    assert Exception.message(error) =~ "such as /terms"
  end
end
