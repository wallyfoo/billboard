defmodule Billboard.EditorLive.FillerTest do
  @moduledoc """
  The filler the page editor warns about, read from the shop's
  components and the parts' blanks as it runs.
  """
  # It reads the configured site, which other tests swap in application
  # env.
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Catalogue
  alias Billboard.EditorLive.Filler
  alias Billboard.Sections.Parts
  alias Billboard.Test.Shop.Section

  defp section(key, type, attrs \\ nil, children \\ []) do
    attrs = attrs || Catalogue.placeholder(type)

    %Section{
      key: key,
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)},
      children: children
    }
  end

  describe "texts/0" do
    test "holds the placeholders' filler" do
      for text <- ["Your heading", "Your band's heading", "Your cards", "Your first point"],
          do: assert(text in Filler.texts())
    end

    test "holds the words a part added in the editor arrives with, and not its address" do
      assert Parts.blank(:action)["label"] == "Your link"

      for text <- ["Your link", "Your point", "Your quote", "What the photograph shows"],
          do: assert(text in Filler.texts())

      refute "/" in Filler.texts()
    end

    test "leaves out the placeholder of a component whose placeholder is fit to keep" do
      refute "What's on" in Filler.texts()
    end

    test "a site's part left as its blank is filler" do
      put_site!(components: [Billboard.Test.Notes])
      assert "Your question" in Filler.texts()
    end
  end

  describe "warnings/1" do
    test "warns about a section still holding its filler" do
      assert [%{level: :warning, key: "new", message: message}] =
               Filler.warnings([section("new", :hero)])

      assert message =~ "hasn't been written yet"
      assert message =~ "“Your heading”"
    end

    test "says nothing once the filler is replaced" do
      assert [] = Filler.warnings([section("written", :hero, %{heading: "Ours"})])
    end

    test "a component whose placeholder is fit to keep isn't filler" do
      assert [] = Filler.warnings([section("news", :news)])
    end

    test "looks inside two columns" do
      columns = section("pair", :columns, %{}, [section("left", :details)])
      assert [%{key: "left"}] = Filler.warnings([columns])
    end
  end
end
