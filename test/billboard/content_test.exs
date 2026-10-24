defmodule Billboard.ContentTest do
  use Billboard.Test.DataCase, async: true

  alias Billboard.Test
  alias Billboard.Test.Shop

  test "holds the site's components, in order, each tagged by its key" do
    types = Shop.Content.subtype_constraints()[:types]

    assert Keyword.keys(types) ==
             ~w(hero band cards text points text_media details reviews news columns shared)a

    for {key, module} <- [
          hero: Billboard.Components.Hero,
          band: Billboard.Components.Band,
          cards: Test.Cards,
          text: Test.Text,
          points: Billboard.Components.Points,
          text_media: Billboard.Components.TextMedia,
          details: Billboard.Components.Details,
          reviews: Billboard.Components.Reviews,
          news: Billboard.Components.News,
          columns: Test.Columns,
          shared: Test.Shared
        ] do
      assert types[key] == [type: module, tag: :component, tag_value: key]
    end
  end

  test "names its site" do
    assert Shop.Content.billboard_site() == Shop
  end

  test "stores a section's content as its type and value" do
    %{id: id} = section_fixture(version_fixture(), :text, %{body: "Words"})

    %{rows: [[content]]} =
      Test.Repo.query!("SELECT content FROM billboard_sections WHERE id = $1", [
        Ecto.UUID.dump!(id)
      ])

    assert content == %{"type" => "text", "value" => %{"body" => "Words", "component" => "text"}}
  end
end
