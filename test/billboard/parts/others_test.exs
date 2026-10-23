defmodule Billboard.Parts.OthersTest do
  @moduledoc "A head, a quote, and a detail. Built in memory, as a component's content would be."
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Parts

  setup do: put_site!(actions: Billboard.Test.Actions, example_path: "/the-salon")

  defp part!(module, attrs) do
    module
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!()
  end

  describe "a head" do
    test "needs a heading, and may carry one action" do
      assert %Parts.Head{heading: "Our team", action: %Parts.Action{kind: :visit}} =
               part!(Parts.Head, %{heading: "Our team", action: %{kind: :visit}})

      assert_raise Ash.Error.Invalid, fn -> part!(Parts.Head, %{eyebrow: "Meet"}) end
    end
  end

  describe "a quote" do
    test "needs a body" do
      assert %Parts.Quote{body: "Lovely.", name: "Sam"} =
               part!(Parts.Quote, %{body: "Lovely.", name: "Sam"})

      assert_raise Ash.Error.Invalid, fn -> part!(Parts.Quote, %{name: "Sam"}) end
    end
  end

  describe "a detail" do
    test "needs a label and a body, and has its own id" do
      assert %Parts.Detail{label: "Parking", only_for_group: nil, id: id} =
               part!(Parts.Detail, %{label: "Parking", body: "On the street."})

      assert is_binary(id)

      assert_raise Ash.Error.Invalid, fn -> part!(Parts.Detail, %{label: "Parking"}) end
    end
  end
end
