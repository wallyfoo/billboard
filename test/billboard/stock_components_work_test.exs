defmodule Billboard.StockComponentsWorkTest do
  @moduledoc """
  Every stock component passes assert_component_works/2, on the shop, and
  so do the shop's own, but Unwritten and Misdrawn, which
  `component_case_test.exs` fails on purpose.
  """
  use Billboard.ComponentCase,
    endpoint: Billboard.Test.Endpoint,
    repo: Billboard.Test.Repo,
    async: false

  alias Billboard.ComponentCase.Render
  alias Billboard.Components

  @reviews [%{id: "r1", name: "Ana", reviewed_on: ~D[2026-10-01], quote: "Lovely."}]
  @news [%{id: "n1", published_on: ~D[2026-10-02], title: "Open late", body: "On Fridays."}]

  for component <- [
        Components.Hero,
        Components.Band,
        Components.Points,
        Components.TextMedia,
        Components.Details,
        Components.Columns
      ] do
    test "#{inspect(component)} works" do
      assert_component_works(unquote(component))
    end
  end

  # Reviews and News draw the rows a site's `Billboard.Data` gives them,
  # which `data:` stands in for.
  test "Reviews works, with the rows the site's data gives" do
    assert_component_works(Components.Reviews, data: @reviews)
  end

  test "News works, with the posts the site's data gives" do
    assert_component_works(Components.News, data: @news)
  end

  # A Shared section has no placeholder: the editor gives it the key of a
  # library section, which `attrs:` stands in for, and `library:` holds.
  test "Shared works, drawing a library section" do
    band = Render.section(:band, %{heading: "From the library"}, "promo")
    library = Render.version([band])

    assert_component_works(Components.Shared, attrs: %{key: "promo"}, library: library)
  end

  for component <- [Billboard.Test.Cards, Billboard.Test.Text, Billboard.Test.Notes] do
    test "the shop's own #{inspect(component)} works" do
      assert_component_works(unquote(component))
    end
  end
end
