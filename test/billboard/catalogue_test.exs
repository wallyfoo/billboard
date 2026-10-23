defmodule Billboard.CatalogueTest do
  @moduledoc """
  What the builder knows about each of the shop's components, read from
  their `component` sections.
  """
  use ExUnit.Case, async: true

  alias Billboard.Catalogue
  alias Billboard.Catalogue.Entry

  test "lists the site's components in its order, the palette's" do
    assert Catalogue.keys() == [:hero, :band, :cards, :text, :columns, :shared]
    assert Enum.map(Catalogue.entries(), & &1.key) == Catalogue.keys()
  end

  test "groups components for the palette, in the order the components first name each category" do
    assert Catalogue.categories() == [:opener, :band, :paper, :layout, :special]

    for key <- Catalogue.keys() do
      assert [_] = for(c <- Catalogue.categories(), key in keys_in(c), do: c)
    end
  end

  test "labels a component, and raises for an unknown one" do
    assert Catalogue.label(:hero) == "Hero"
    assert_raise KeyError, fn -> Catalogue.fetch!(:nope) end
  end

  test "an entry allows every kind of page, or only the kinds it lists" do
    every = Catalogue.fetch!(:cards)
    free = Catalogue.fetch!(:columns)

    assert every.kinds == :all
    assert Entry.allows?(every, :free)
    assert Entry.allows?(every, :item)
    assert free.kinds == [:free]
    assert Entry.allows?(free, :free)
    refute Entry.allows?(free, :item)
  end

  test "an entry's placeholder is the component's own, less what the site doesn't offer" do
    assert Catalogue.placeholder(:hero) == %{heading: "Your heading"}
    assert Catalogue.fetch!(:hero).placeholder == %{heading: "Your heading"}
  end

  defp keys_in(category), do: for(e <- Catalogue.entries(), e.category == category, do: e.key)
end
