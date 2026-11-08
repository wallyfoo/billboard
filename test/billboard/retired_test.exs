defmodule Billboard.RetiredTest do
  @moduledoc """
  A stored section whose component the site no longer has, as when a
  site takes its own component out of `components:`: it reads, as
  `Billboard.Content.Retired`, is written back as it was stored, draws
  nothing for visitors, blocks a commit, and gives way to `put_page/3`.
  """
  use Billboard.Test.DataCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Billboard.Content.Retired
  alias Billboard.{Pages, Sections}
  alias Billboard.Test.Shop

  @opts [authorize?: false]
  @fields %{"title" => "Old leaflet", "service" => "therapy"}

  # Each refresh of the cache warns of a leaflet while it's live; the
  # warning's own test captures it.
  @moduletag :capture_log

  setup :preserve_cache

  defp hero, do: %{type: :hero, content: %{heading: "About us"}}
  defp text(body), do: %{type: :text, content: %{body: body}}

  # The about page, live, with a section of `leaflet`, a component the
  # shop has never had, between its hero and its words. A live section
  # can't be moved through its actions, so the words' place is written
  # to the table, as the leaflet is.
  defp live_with_leaflet do
    {:ok, live} = Shop.Pages.put_page("/about", [hero(), text("Since 1999.")], @opts)

    Billboard.Test.Repo.query!(
      "UPDATE billboard_sections SET position = 2 WHERE version_id = $1 AND position = 1",
      [Ecto.UUID.dump!(live.id)]
    )

    key = stored_section_fixture(live, :leaflet, @fields, position: 1)
    capture_log(fn -> Billboard.Cache.refresh() end)
    {live, key}
  end

  defp types(version), do: Enum.map(version.sections, & &1.content.type)

  defp render_page(version) do
    assigns = %{version: version}

    ~H"""
    <Sections.page version={@version} flash={%{}} site={%{name: "The shop"}} current_path="/about" />
    """
    |> rendered_to_string()
    |> LazyHTML.from_document()
  end

  describe "reading" do
    test "a live version holding it reads, the section as its key and fields" do
      {live, key} = live_with_leaflet()

      assert {:ok, versions} = Shop.Pages.list_live_versions(@opts)
      version = Enum.find(versions, &(&1.id == live.id))
      assert types(version) == [:hero, :retired, :text]
      retired = Enum.at(version.sections, 1)
      assert retired.key == key
      assert Retired.retired?(retired)

      assert %Ash.Union{type: :retired, value: %Retired{component: "leaflet", fields: @fields}} =
               retired.content
    end

    test "a draft made from it holds it as it was stored, under its old key" do
      {live, key} = live_with_leaflet()
      stored = stored_content(live.id, key)

      assert {:ok, draft} = Shop.Pages.edit_page("/about", @opts)
      assert types(draft) == [:hero, :retired, :text]
      assert stored_content(draft.id, key) == stored
      assert stored["type"] == "leaflet"
    end

    # The site is only a vehicle for the content union, so what its own
    # verifiers say of it, on stderr, is beside the point.
    test "a component may not take the key :retired" do
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        assert_raise ArgumentError, ~r/has the key :retired, which the content union keeps/, fn ->
          defmodule RetiredKeyed do
            use Billboard.Component

            component do
              key :retired
              label "Retired"
              hint "Taken."
              category :content
              renderer Billboard.Sections.Words
            end
          end

          defmodule RetiredKeyedSite do
            use Billboard.Site,
              otp_app: :billboard,
              resources: [content: Billboard.RetiredTest.RetiredKeyedContent],
              components: [Billboard.RetiredTest.RetiredKeyed]
          end

          defmodule RetiredKeyedContent do
            use Billboard.Content, site: Billboard.RetiredTest.RetiredKeyedSite
          end
        end
      end)
    end
  end

  describe "visitors" do
    test "their page draws nothing for it, and the sections either side meet" do
      {_live, key} = live_with_leaflet()
      page = Pages.page_for("/about")
      assert types(page) == [:hero, :retired, :text]

      doc = render_page(page)
      assert LazyHTML.query(doc, "#section-#{key}") |> Enum.count() == 0
      assert LazyHTML.query(doc, "main section.page-section") |> Enum.count() == 1
      refute LazyHTML.text(doc) =~ "Old leaflet"
    end

    test "filling the cache logs a warning naming the key and the page, once for each" do
      {_live, key} = live_with_leaflet()
      log = capture_log(fn -> Billboard.Cache.refresh() end)

      assert [line] = Regex.scan(~r/“leaflet”/, log)
      assert line == ["“leaflet”"]
      assert log =~ "page /about"
      assert log =~ key
      assert log =~ "migrate_sections/3"
    end

    test "its data isn't read" do
      {_live, _key} = live_with_leaflet()
      assert Billboard.Resolver.resolve(Pages.page_for("/about")) == %{}
    end

    test "a column holding one draws the other column alone" do
      columns = %{
        type: :columns,
        content: %{variant: :even},
        children: [text("Left"), text("Right")]
      }

      {:ok, live} = Shop.Pages.put_page("/", [hero(), columns], @opts)
      [_hero, %{children: [left, _right]}] = live.sections

      Billboard.Test.Repo.query!(
        ~s(UPDATE billboard_sections SET content = '{"type": "leaflet", "value": {}}' WHERE id = $1),
        [Ecto.UUID.dump!(left.id)]
      )

      capture_log(fn -> Billboard.Cache.refresh() end)
      page = Pages.page_for("/")
      [_hero, %{children: [retired, _right]}] = page.sections
      assert Retired.retired?(retired)

      text = page |> render_page() |> LazyHTML.query("[data-columns]") |> LazyHTML.text()
      assert text =~ "Right"
      refute text =~ "Left"
    end

    test "a Shared section placing one from the library draws nothing" do
      {:ok, library} = Shop.Pages.put_page(nil, [], @opts)
      stored_section_fixture(library, :leaflet, %{"title" => "Old leaflet"}, key: "old-promo")

      {:ok, _live} =
        Shop.Pages.put_page(
          "/about",
          [hero(), %{type: :shared, content: %{key: "old-promo"}}, text("After")],
          @opts
        )

      capture_log(fn -> Billboard.Cache.refresh() end)
      doc = render_page(Pages.page_for("/about"))
      assert LazyHTML.query(doc, "main section.page-section") |> Enum.count() == 1
      refute LazyHTML.text(doc) =~ "Old leaflet"
    end
  end

  describe "publishing" do
    test "is refused while the draft holds it, naming its key, and goes once it's removed" do
      {_live, key} = live_with_leaflet()
      {:ok, draft} = Shop.Pages.edit_page("/about", @opts)

      assert {:error, error} = Shop.Pages.commit_page("/about", @opts)
      assert Exception.message(error) =~ "“leaflet”, is no longer on the site"

      {:ok, section} = Shop.Pages.get_section_by_key(draft.id, key, @opts)
      :ok = Shop.Pages.destroy_section(section, @opts)

      assert {:ok, _live} = Shop.Pages.commit_page("/about", @opts)
      assert types(Pages.page_for("/about")) == [:hero, :text]
    end

    test "the rules mark it as an error, and hand the site's own rules none" do
      put_shop!(rules: [Billboard.Test.GroundRule])
      {_live, key} = live_with_leaflet()
      page = Billboard.Directory.fetch!("/about")
      sections = Pages.page_for("/about").sections

      assert [%{level: :error, key: ^key, message: message}] =
               Billboard.Rules.check(page, sections, %{})

      assert message =~ "remove the section to publish the page"
    end
  end

  test "put_page/3 replaces a page that holds it" do
    {_live, _key} = live_with_leaflet()
    {:ok, _draft} = Shop.Pages.edit_page("/about", @opts)

    assert {:ok, live} = Shop.Pages.put_page("/about", [hero(), text("New")], @opts)
    assert types(live) == [:hero, :text]
    assert types(Pages.page_for("/about")) == [:hero, :text]
  end
end
