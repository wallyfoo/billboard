defmodule Billboard.SurfaceOfferedTest do
  # Changes application env, which every test reads, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Ash.Error.Changes.InvalidAttribute
  alias Billboard.Test.Item
  alias Billboard.Validations.SurfaceOffered

  setup do
    put_site!(offered: [page: ["plain"], stand_out: ["loud"], card: ["plain"]])
  end

  describe "init/1" do
    test "needs a kind, and names the fix" do
      assert {:error, message} = SurfaceOffered.init([])
      assert message =~ "kind: :card"
    end

    test "keeps to :surface unless given a field" do
      assert {:ok, opts} = SurfaceOffered.init(kind: :card)
      assert opts[:field] == :surface

      assert {:ok, opts} = SurfaceOffered.init(kind: :card, field: :ground)
      assert opts[:field] == :ground
    end
  end

  describe "a part's surface" do
    test "may be one the site offers its kind" do
      assert {:ok, %Item{surface: "plain"}} = create(%{title: "One", surface: "plain"})
    end

    test "may be nil, which draws it on its section's" do
      assert {:ok, %Item{surface: nil}} = create(%{title: "One"})
    end

    test "is refused one the site doesn't offer its kind" do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               create(%{title: "One", surface: "loud"})

      assert %InvalidAttribute{field: :surface} = error
      assert error.message == "“loud” isn't a surface the site offers here"
    end

    test "is refused one the site doesn't offer, on update" do
      {:ok, item} = create(%{title: "One"})

      assert {:error, %Ash.Error.Invalid{errors: [%InvalidAttribute{field: :surface}]}} =
               item |> Ash.Changeset.for_update(:update, %{surface: "loud"}) |> Ash.update()
    end

    test "keeps one the site has stopped offering while it saves another field" do
      {:ok, item} = create(%{title: "One", surface: "plain"})
      put_site!(offered: [page: ["plain"], stand_out: ["loud"], card: []])

      assert {:ok, %Item{title: "Two", surface: "plain"}} =
               item
               |> Ash.Changeset.for_update(:update, %{title: "Two", surface: "plain"})
               |> Ash.update()
    end
  end

  defp create(params), do: Item |> Ash.Changeset.for_create(:create, params) |> Ash.create()
end
