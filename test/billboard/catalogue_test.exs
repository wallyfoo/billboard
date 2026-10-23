defmodule Billboard.CatalogueTest do
  @moduledoc """
  What the builder knows about each of the shop's components, read from
  their `component` sections.
  """
  # One test swaps the site in application env, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Catalogue
  alias Billboard.Catalogue.Entry

  defmodule Boxed do
    @moduledoc """
    A component whose placeholder sets a look a site may narrow away. No
    shop component's placeholder sets a field a site narrows.
    """
    use Billboard.Component

    component do
      key :boxed
      label "Boxed"
      hint "A few words, in a box or in rows."
      category :paper
      placeholder %{look: :cards, words: "Your words"}
    end

    attributes do
      attribute :look, :atom,
        default: :rows,
        public?: true,
        constraints: [one_of: [:rows, :cards]]

      attribute :words, :string, public?: true
    end
  end

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

    put_site!(components: [Boxed])
    assert Catalogue.placeholder(:boxed) == %{look: :cards, words: "Your words"}

    put_site!(options: [boxed: [look: [:rows]]])
    assert Catalogue.placeholder(:boxed) == %{words: "Your words"}
  end

  defp keys_in(category), do: for(e <- Catalogue.entries(), e.category == category, do: e.key)
end
