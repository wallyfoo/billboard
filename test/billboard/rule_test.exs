defmodule Billboard.RuleTest do
  use ExUnit.Case, async: true

  alias Billboard.Rule

  defmodule NoTwoInARow do
    @behaviour Billboard.Rule

    @impl true
    def check(_page, sections, _shared) do
      for [a, b] <- Enum.chunk_every(sections, 2, 1, :discard),
          a.surface == b.surface,
          do: Rule.error(b, "two sections in a row can't share a ground")
    end
  end

  describe "error/2" do
    test "is about the section it's given, by key" do
      assert Rule.error(%{key: "intro"}, "Too long") ==
               %{level: :error, key: "intro", message: "Too long"}
    end

    test "is about the whole page without a section" do
      assert Rule.error(nil, "No hero") == %{level: :error, key: nil, message: "No hero"}
    end
  end

  describe "warning/2" do
    test "is about the section it's given, by key" do
      assert Rule.warning(%{key: "outro"}, "Ends on a band") ==
               %{level: :warning, key: "outro", message: "Ends on a band"}
    end

    test "is about the whole page without a section" do
      assert Rule.warning(nil, "Quiet") == %{level: :warning, key: nil, message: "Quiet"}
    end
  end

  test "a section without a key can't be named" do
    assert_raise KeyError, fn -> Rule.error(%{title: "x"}, "Nope") end
  end

  test "a rule returns its issues from check/3" do
    sections = [
      %{key: "a", surface: "loud"},
      %{key: "b", surface: "loud"},
      %{key: "c", surface: "plain"}
    ]

    assert NoTwoInARow.check(%{}, sections, %{}) == [
             %{level: :error, key: "b", message: "two sections in a row can't share a ground"}
           ]
  end
end
