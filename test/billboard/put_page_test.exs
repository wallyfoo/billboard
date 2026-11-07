defmodule Billboard.PutPageTest do
  @moduledoc """
  `Billboard.Pages.put_page/3`, which a site's seeds call: it makes a
  page hold exactly the sections it's given, and publishes them, however
  often it runs.
  """
  use Billboard.Test.DataCase, async: false

  alias Billboard.Test.Shop

  @opts [authorize?: false]

  setup :preserve_cache

  defp hero(heading \\ "Welcome"), do: %{type: :hero, content: %{heading: heading}}
  defp text(body), do: %{type: :text, content: %{body: body}}

  defp types(version), do: Enum.map(version.sections, & &1.content.type)

  test "publishes the sections it's given, in order, for visitors" do
    assert {:ok, live} =
             Shop.Pages.put_page(
               "/about",
               [
                 hero("About us"),
                 %{type: :band, key: "visit", surface: "loud", content: %{heading: "Visit"}},
                 Map.put(text("Since 1999."), :anchor, "since")
               ],
               @opts
             )

    assert live.status == :live
    assert types(live) == [:hero, :band, :text]

    shown = Shop.Pages.page_for("/about")
    assert shown.id == live.id
    assert types(shown) == [:hero, :band, :text]
    assert [hero, band, words] = shown.sections
    assert hero.content.value.heading == "About us"
    assert {band.key, band.surface} == {"visit", "loud"}
    assert words.anchor == "since"
    assert {:ok, nil} = Shop.Pages.draft_for("/about", @opts)
  end

  test "running again puts the same page back, over what was published and drafted since" do
    sections = [hero(), text("First")]
    {:ok, _live} = Shop.Pages.put_page("/about", sections, @opts)

    {:ok, _} = Shop.Pages.put_page("/about", [hero("Changed")], @opts)
    {:ok, _draft} = Shop.Pages.edit_page("/about", @opts)

    assert {:ok, live} = Shop.Pages.put_page("/about", sections, @opts)
    assert types(live) == [:hero, :text]
    assert hd(live.sections).content.value.heading == "Welcome"
    assert {:ok, nil} = Shop.Pages.draft_for("/about", @opts)
    assert Shop.Pages.page_for("/about").id == live.id
  end

  test "puts a Two columns section's two sections inside it" do
    columns = %{
      type: :columns,
      content: %{variant: :wide_left},
      children: [text("Left"), text("Right")]
    }

    assert {:ok, live} = Shop.Pages.put_page("/", [hero(), columns], @opts)
    [_hero, columns] = live.sections
    assert Enum.map(columns.children, & &1.content.value.body) == ["Left", "Right"]
  end

  test "with publish: false, leaves a draft for the editor, and visitors see what they did" do
    before = Shop.Pages.page_for("/about")

    assert {:ok, draft} =
             Shop.Pages.put_page("/about", [hero(), text("Soon")], [publish: false] ++ @opts)

    assert draft.status == :draft
    assert types(draft) == [:hero, :text]
    assert Shop.Pages.page_for("/about").sections == before.sections
  end

  test "changes nothing when the page breaks a rule, and says which" do
    {:ok, live} = Shop.Pages.put_page("/about", [hero()], @opts)

    assert {:error, error} = Shop.Pages.put_page("/about", [text("No hero")], @opts)
    assert Exception.message(error) =~ "the page opens with its hero"
    assert Shop.Pages.page_for("/about").id == live.id
    assert {:ok, nil} = Shop.Pages.draft_for("/about", @opts)
  end

  test "refuses content its component refuses, and a page the site hasn't got" do
    assert {:error, %Ash.Error.Invalid{}} =
             Shop.Pages.put_page("/about", [%{type: :hero, content: %{heading: nil}}], @opts)

    assert {:error, error} = Shop.Pages.put_page("/nowhere", [hero()], @opts)
    assert Exception.message(error) =~ "there is no such page"
  end

  test "needs an actor, or authorize?: false, as every write does" do
    assert {:error, %{class: :forbidden}} = Shop.Pages.put_page("/about", [hero()])
    assert {:ok, _live} = Shop.Pages.put_page("/about", [hero()], actor: admin())
  end

  test "names what's wrong with a section it can't read" do
    assert_raise ArgumentError, ~r/`type:`, a component's key/, fn ->
      Shop.Pages.put_page("/about", [{:hero, %{heading: "x"}}], @opts)
    end

    assert_raise ArgumentError, ~r/keys it doesn't take: \[:fields\]/, fn ->
      Shop.Pages.put_page("/about", [Map.put(hero(), :fields, %{})], @opts)
    end
  end
end
