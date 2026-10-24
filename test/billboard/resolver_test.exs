defmodule Billboard.ResolverTest do
  @moduledoc """
  The page's data, read through the site's `Billboard.Data`: the shop's
  is `Billboard.Test.Data`, whose rows a test puts in its process
  dictionary, and which notes each read.
  """
  # Refreshes the pages cache and swaps the site, so not async.
  use Billboard.Test.DataCase, async: false

  alias Billboard.Components.Reviews
  alias Billboard.Resolver
  alias Billboard.Test.{Data, Shop}

  # A data module that forgets to hand back what it read.
  defmodule BadData do
    @behaviour Billboard.Data

    @impl true
    def fetch(%Reviews{}, _context, _loaded), do: {:ok, ["a review"]}
    def fetch(_content, _context, _loaded), do: :none
  end

  # A data module that answers with data but loses what the page has read.
  defmodule LostLoaded do
    @behaviour Billboard.Data

    @impl true
    def fetch(%Reviews{}, _context, _loaded), do: {:ok, ["a review"], nil}
    def fetch(_content, _context, _loaded), do: :none
  end

  # A data module whose reviews are the page's context.
  defmodule ContextData do
    @behaviour Billboard.Data

    @impl true
    def fetch(%Reviews{}, context, loaded), do: {:ok, context, loaded}
    def fetch(_content, _context, _loaded), do: :none
  end

  @opts [authorize?: false]

  setup :preserve_cache

  defp version(sections), do: %{sections: sections}

  defp s(key, type, attrs \\ %{}, children \\ []),
    do: %Shop.Section{
      key: key,
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)},
      children: children
    }

  # News needs a head.
  @news %{head: %{heading: "What's on"}}
  @review %{id: "r1", name: "Ann", reviewed_on: ~D[2026-01-05], quote: "Lovely."}
  @post %{id: "n1", published_on: ~D[2026-02-01], title: "Open late", body: "Till nine."}

  setup do
    Process.put(:shop_reviews, [@review])
    Process.put(:shop_news, [@post])
    :ok
  end

  test "loads only what the sections need" do
    assert Resolver.resolve(version([s("h", :hero, %{heading: "x"})])) == %{}
    assert Data.reads() == []
  end

  test "two sections of a kind, as a draft may hold, read it once" do
    once = [s("r", :reviews), s("n", :news, @news)]
    twice = once ++ [s("r2", :reviews), s("n2", :news, @news)]

    assert Resolver.resolve(version(twice)) == %{
             "r" => [@review],
             "n" => [@post],
             "r2" => [@review],
             "n2" => [@post]
           }

    assert Data.reads() == [:reviews, {:news, 2}]
  end

  test "news sections of different limits read each limit once" do
    sections = [
      s("n1", :news, Map.put(@news, :limit, 1)),
      s("n3", :news, Map.put(@news, :limit, 3)),
      s("n1b", :news, Map.put(@news, :limit, 1))
    ]

    assert Resolver.resolve(version(sections)) == %{
             "n1" => [@post],
             "n3" => [@post],
             "n1b" => [@post]
           }

    assert Data.reads() == [{:news, 1}, {:news, 3}]
  end

  test "children of Two columns are resolved like top-level ones" do
    data =
      Resolver.resolve(
        version([
          s("r", :reviews),
          s("cols", :columns, %{}, [s("n", :news, @news), s("r2", :reviews)])
        ])
      )

    assert data == %{"r" => [@review], "n" => [@post], "r2" => [@review]}
    assert Data.reads() == [:reviews, {:news, 2}]
  end

  test "resolves the data sections of a page as visitors see it" do
    {:ok, page} = Shop.Pages.ensure_page("/about", @opts)
    live = Ash.Seed.seed!(Shop.Version, %{page_id: page.id, status: :live})
    seed_section_fixture(live, :hero, %{heading: "About us"}, %{position: 0})
    seed_section_fixture(live, :reviews, %{}, %{key: "reviews", position: 1})
    columns = seed_section_fixture(live, :columns, %{}, %{key: "visit", position: 2})

    seed_section_fixture(live, :news, Map.put(@news, :limit, 1), %{
      key: "whats-on",
      parent_id: columns.id,
      position: 0
    })

    Billboard.Cache.refresh()

    assert Resolver.resolve(Shop.Pages.page_for("/about")) == %{
             "reviews" => [@review],
             "whats-on" => [@post]
           }
  end

  test "raises when a Two columns section's children aren't loaded" do
    columns = %{s("cols", :columns) | children: %Ash.NotLoaded{}}

    assert_raise ArgumentError, ~r/load the children of Two columns section "cols"/, fn ->
      Resolver.resolve(version([columns]))
    end
  end

  test "a site with no data module reads nothing" do
    sections = [s("r", :reviews), s("n", :news, @news)]
    put_site!(data: nil)

    assert Resolver.resolve(version(sections)) == %{}
    assert Data.reads() == []
  end

  test "the page's context reaches the data module, an empty map unless given" do
    sections = [s("r", :reviews)]
    put_site!(data: ContextData)

    assert Resolver.resolve(version(sections), %{group: "colour"}) == %{
             "r" => %{group: "colour"}
           }

    assert Resolver.resolve(version(sections)) == %{"r" => %{}}
  end

  test "raises, naming the fix, when the data module returns neither data nor :none" do
    sections = [s("h", :hero, %{heading: "x"}), s("r", :reviews)]
    put_site!(data: BadData)

    message =
      ~s(Billboard.ResolverTest.BadData.fetch/3 returned {:ok, ["a review"]} for section "r". ) <>
        "Return `{:ok, value, loaded}` (`Billboard.Data.once/3` gives one) or `:none`."

    assert_raise ArgumentError, message, fn ->
      Resolver.resolve(version(sections))
    end
  end

  test "raises, naming the fix, when the data module loses what the page has read" do
    sections = [s("r", :reviews)]
    put_site!(data: LostLoaded)

    message =
      ~s(Billboard.ResolverTest.LostLoaded.fetch/3 returned {:ok, ["a review"], nil} for section "r". ) <>
        "Return `{:ok, value, loaded}` (`Billboard.Data.once/3` gives one) or `:none`."

    assert_raise ArgumentError, message, fn ->
      Resolver.resolve(version(sections))
    end
  end

  test "raises for unloaded children even with no data module" do
    columns = %{s("cols", :columns) | children: %Ash.NotLoaded{}}
    put_site!(data: nil)

    assert_raise ArgumentError, ~r/load the children of Two columns section "cols"/, fn ->
      Resolver.resolve(version([columns]))
    end
  end
end
