defmodule Billboard.Guides.SeedsTest do
  @moduledoc """
  The page kinds guide's seeds (`MySite.Pages.Seeds`): on a site with
  the getting started guide's surfaces, paper and the band, its home page
  is published as the guide says, and running it again puts the same
  page back.
  """
  use Billboard.Test.DataCase, async: false

  alias Billboard.Test.Shop

  setup :preserve_cache

  setup do
    put_shop!(
      surfaces: [%{name: "paper", label: "Paper"}, %{name: "band", label: "Band"}],
      offered: [page: ["paper"], stand_out: ["band"], card: []]
    )
  end

  test "publishes the home page, with its sections and their content" do
    assert {:ok, live} = MySite.Pages.Seeds.home()

    shown = Billboard.Pages.page_for("/")
    assert shown.id == live.id

    assert Enum.map(shown.sections, &{&1.key, &1.content.type}) == [
             {"home-hero", :hero},
             {"home-points", :points},
             {"home-band", :band},
             {"home-about", :text_media}
           ]

    [hero, points, band, about] = shown.sections
    assert [%{style: :primary}, %{style: :secondary}] = hero.content.value.actions
    assert hero.content.value.photo.label == "The consulting room"
    assert points.anchor == "how-we-work"
    assert length(points.content.value.points) == 3
    assert band.surface == "band"
    assert about.content.value.photo.label == "The team, outside"
  end

  test "running again changes nothing a visitor sees, and leaves no draft" do
    {:ok, first} = MySite.Pages.Seeds.home()
    {:ok, second} = MySite.Pages.Seeds.home()

    assert second.id != first.id
    assert Enum.map(second.sections, & &1.key) == Enum.map(first.sections, & &1.key)
    assert {:ok, nil} = Shop.Pages.draft_for("/", authorize?: false)
  end
end
