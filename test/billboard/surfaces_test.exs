defmodule Billboard.SurfacesTest do
  # Changes application env, which every test reads, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Surfaces
  alias Billboard.Test.{Banner, Cards, Masthead, Note}

  setup do
    put_site!(components: [Banner, Cards, Masthead, Note])
  end

  describe "the test site's surfaces" do
    test "are plain, then loud, with the page's own first" do
      assert Surfaces.all() == [%{name: "plain", label: "Plain"}, %{name: "loud", label: "Loud"}]
    end

    test "offer plain to a page section, and loud to a stand-out one" do
      assert Surfaces.offered(:page) == ["plain"]
      assert Surfaces.offered(:stand_out) == ["loud"]
    end

    test "default to the first surface each kind is offered" do
      assert Surfaces.default(:page) == "plain"
      assert Surfaces.default(:stand_out) == "loud"
    end

    test "offer cards none, so a card is drawn on its section's surface" do
      assert Surfaces.offered(:card) == []
      assert Surfaces.card(nil) == nil
      assert Surfaces.card("plain") == nil
    end

    test "give a card no default of its own, and say so" do
      assert_raise ArgumentError, ~r/:card isn't a section's kind/, fn ->
        Surfaces.default(:card)
      end
    end

    test "offer nothing to a kind they don't know, and say so" do
      assert_raise ArgumentError, ~r/no surfaces for the kind :sidebar. Add `sidebar: /, fn ->
        Surfaces.offered(:sidebar)
      end
    end
  end

  describe "a section's kind" do
    test "is its component's surface kind" do
      assert Surfaces.kind(:banner) == :stand_out
    end

    test "is page for a component that doesn't say" do
      assert Surfaces.kind(:cards) == :page
      assert Surfaces.kind(:note) == :page
    end

    test "raises for a type the site has no component for" do
      assert_raise ArgumentError, ~r/no component :nope/, fn -> Surfaces.kind(:nope) end
    end
  end

  describe "the surface a section is drawn on" do
    test "is its kind's default when it names none" do
      assert Surfaces.resolve(:cards, nil) == "plain"
      assert Surfaces.resolve(:banner, nil) == "loud"
    end

    test "is its kind's default when it names one its kind isn't offered" do
      assert Surfaces.resolve(:cards, "loud") == "plain"
      assert Surfaces.resolve(:banner, "plain") == "loud"
      assert Surfaces.resolve(:cards, "lilac") == "plain"
    end

    test "is the one it names while its kind is offered it" do
      put_site!(offered: [page: ["plain", "loud"], stand_out: ["loud"]])

      assert Surfaces.resolve(:cards, "loud") == "loud"
      assert Surfaces.resolve(:cards, "plain") == "plain"
    end
  end

  describe "who chooses a section's surface" do
    test "the section does, for a component that doesn't say" do
      for type <- [:cards, :note] do
        assert Surfaces.taken_from(type, nil) == nil
        assert Surfaces.choosable?(type, nil)
      end
    end

    test "the library section does, for a component drawn from the library" do
      assert Surfaces.taken_from(:banner, nil) == :library
      refute Surfaces.choosable?(:banner, nil)
    end

    test "the layout does, for a component the layout draws" do
      assert Surfaces.taken_from(:masthead, nil) == :layout
      refute Surfaces.choosable?(:masthead, nil)
    end

    test "the parent does, for a column" do
      parent_id = Ash.UUID.generate()

      assert Surfaces.taken_from(:cards, parent_id) == :parent
      refute Surfaces.choosable?(:cards, parent_id)
    end
  end

  describe "a site with more surfaces" do
    setup do
      put_site!(
        surfaces: [
          %{name: "bg", label: "Background"},
          %{name: "night", label: "Night"},
          %{name: "inverse", label: "Inverse"}
        ],
        offered: [page: ["bg"], stand_out: ["night", "inverse"], card: ["bg", "night"]]
      )
    end

    test "lists them" do
      assert Enum.map(Surfaces.all(), & &1.name) == ["bg", "night", "inverse"]
    end

    test "offers what it names, in its order" do
      assert Surfaces.offered(:page) == ["bg"]
      assert Surfaces.offered(:stand_out) == ["night", "inverse"]
      assert Surfaces.default(:stand_out) == "night"
    end

    test "can offer cards surfaces of their own" do
      assert Surfaces.offered(:card) == ["bg", "night"]
      assert Surfaces.card("night") == "night"
      assert Surfaces.card("inverse") == nil
      assert Surfaces.card(nil) == nil
    end
  end

  describe "a site that leaves a kind out of its offer" do
    setup do
      put_site!(offered: [page: ["plain"]])
    end

    test "offers a section's kind nothing, and says so" do
      assert_raise ArgumentError, ~r/no surfaces for the kind :stand_out/, fn ->
        Surfaces.offered(:stand_out)
      end
    end

    test "offers cards none" do
      assert Surfaces.offered(:card) == []
    end
  end

  describe "an offer that can't be drawn" do
    test "raises for a name the site doesn't list" do
      put_site!(offered: [page: ["plain", "lilac"]])

      assert_raise ArgumentError,
                   ~r/offers :page the surface “lilac”, which isn't among its surfaces. Add it/,
                   fn -> Surfaces.offered(:page) end
    end

    test "raises for a kind offered nothing" do
      put_site!(offered: [page: []])

      assert_raise ArgumentError, ~r/no surfaces for the kind :page/, fn ->
        Surfaces.offered(:page)
      end
    end

    test "raises for a card surface the site doesn't list" do
      put_site!(offered: [page: ["plain"], card: ["lilac"]])

      assert_raise ArgumentError, ~r/offers :card the surface “lilac”/, fn ->
        Surfaces.offered(:card)
      end
    end
  end
end
