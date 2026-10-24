defmodule Billboard.EditorLive.SectionEditorTest do
  # Every change here makes or changes a draft, and the pages it opens are
  # put live in the shared cache, which other tests read.
  use Billboard.Test.LiveCase, async: false

  alias Billboard.Pages
  alias Billboard.Test.{SectionEditorHost, Shop}
  alias Billboard.Uploads

  @opts [authorize?: false]

  # A PNG signature, enough for `Uploads.store_image/1`.
  @png <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, "IHDR">>

  setup :preserve_cache

  ## The shop's pages, put live as a commit would

  # The home page: a hero with a photograph and no actions, text and
  # image with an action, and words.
  defp home! do
    make_live("/", [
      {"hero", :hero, %{heading: "Everything for the shop", photo: %{label: "The shop floor"}}},
      {"range", :text_media,
       %{variant: :text_only, head: %{heading: "Our range"}, actions: [%{kind: :call}]}},
      {"welcome", :text, %{body: "Come in."}, anchor: "welcome"}
    ])
  end

  # The home page again, as a shop front: a hero with three actions, and
  # text and image whose heading has one.
  defp storefront! do
    make_live("/", [
      {"hero", :hero,
       %{
         heading: "Everything for the shop",
         actions: [
           %{kind: :call},
           %{label: "Our story", path: "/about"},
           %{label: "Delivery", path: "/terms"}
         ]
       }},
      {"range", :text_media,
       %{
         variant: :text_only,
         head: %{heading: "Our range", action: %{label: "See all", path: "/about"}}
       }}
    ])
  end

  # The about page: two Points, the first with a link on its first point,
  # What's on, a quote band, the library's band shared, and Two columns.
  defp about! do
    make_live("/about", [
      {"hero", :hero, %{heading: "About us"}},
      {"also-here", :points,
       %{
         columns: 2,
         points: [
           %{
             title: "Step-free",
             body: "A ramp at the door.",
             link: %{label: "Getting here", path: "/terms"}
           },
           %{title: "Quiet hours", body: "Every morning."}
         ]
       }, anchor: "also-here"},
      {"story", :points, %{points: [%{title: "Founded"}, %{title: "Grown"}, %{title: "Here"}]},
       anchor: "story"},
      {"whats-on", :news, %{head: %{heading: "What's on"}}},
      {"late-opening", :band,
       %{variant: :quote_left, quote: %{body: "Open till eight."}, body: "On Thursdays."}},
      {"visit", :columns, %{},
       children: [
         {"where", :details, %{items: [%{label: "Where", body: "On the high street."}]}},
         {"when", :text, %{body: "Open every day."}}
       ]},
      {"promo-here", :shared, %{key: "promo"}}
    ])
  end

  # An item page, whose hero takes its words from the product, and its
  # details, one shown only in an aisle the shop no longer has.
  defp item! do
    make_live("/items/:slug", [
      {"hero", :hero, %{heading: "An item", bind: :product}},
      {"details", :details,
       %{
         items: [
           %{label: "Delivery", body: "Free over fifty."},
           %{label: "Sizing", body: "Runs small.", only_for_group: "socks"},
           %{label: "Returns", body: "Within thirty days."}
         ]
       }}
    ])
  end

  # The terms page, whose hero is bound to a visit, which keeps its words.
  defp visit! do
    make_live("/terms", [
      {"hero", :hero, %{heading: "Terms", bind: :visit}},
      {"terms", :text, %{body: "Be kind."}}
    ])
  end

  defp make_live(pattern, sections) do
    {:ok, page} = Shop.Pages.ensure_page(pattern, @opts)
    live = Ash.Seed.seed!(Shop.Version, %{page_id: page.id, status: :live})
    place(live, sections, nil)
    Billboard.Cache.refresh()
    :ok
  end

  defp place(live, sections, parent_id) do
    for {section, position} <- Enum.with_index(sections) do
      {key, type, attrs, opts} =
        case section do
          {key, type, attrs} -> {key, type, attrs, []}
          {key, type, attrs, opts} -> {key, type, attrs, opts}
        end

      seeded =
        seed_section_fixture(live, type, attrs, %{
          key: key,
          position: position,
          parent_id: parent_id,
          anchor: opts[:anchor]
        })

      place(live, Keyword.get(opts, :children, []), seeded.id)
    end
  end

  ## Helpers

  # The editor, open on the section with this key.
  defp open(pattern, key) do
    {:ok, lv, _} =
      live_isolated(build_conn(), SectionEditorHost,
        session: %{"pattern" => pattern, "key" => key, "actor" => admin()}
      )

    lv
  end

  # The section with this key in the page's draft.
  defp draft_section(pattern, key) do
    {:ok, draft} = Pages.draft_for(pattern, @opts)
    Shop.Pages.get_section_by_key!(draft.id, key, @opts)
  end

  defp content(pattern \\ "/", key), do: draft_section(pattern, key).content.value

  defp section_of(pattern, type) do
    Enum.find(
      Enum.flat_map(Pages.page_for(pattern).sections, &[&1 | &1.children]),
      &(&1.content.type == type)
    )
  end

  defp no_draft?(pattern), do: Pages.draft_for(pattern, @opts) == {:ok, nil}

  # An event sent to the editor, as the words' hook sends one
  # (`pushEventTo("#section-editor", …)`) and the controls will.
  defp send_editor(lv, event, params),
    do: lv |> with_target("#section-editor") |> render_hook(event, params) |> settled(lv)

  defp change(lv, params), do: send_editor(lv, "change", %{"section" => params})
  defp pick_variant(lv, variant), do: send_editor(lv, "change", %{"variant" => variant})

  defp edit_words(lv, path, text),
    do: send_editor(lv, "edit_words", %{"path" => path, "text" => text})

  # The editor tells its LiveView when it saves (`{:section_saved, key}`),
  # which then reads the page again, after the change's reply. Waiting for
  # that read keeps a test from ending while it's still in the database.
  defp settled(html, lv) do
    _ = render(lv)
    html
  end

  # A photograph saves as soon as it has arrived.
  defp upload_photo(lv, key, content) do
    lv
    |> file_input("#photo-form-#{key}", :photo, [
      %{name: "room.png", content: content, type: "image/png"}
    ])
    |> render_upload("room.png")
    |> settled(lv)
  end

  defp describe_photo(lv, key, params),
    do: lv |> form("#photo-form-#{key}") |> render_change(%{"photo" => params}) |> settled(lv)

  describe "the editor" do
    setup do: home!()

    test "is known by its section, names it, and has Done" do
      text_media = section_of("/", :text_media)
      lv = open("/", text_media.key)

      assert has_element?(lv, "#section-editor[data-section='#{text_media.key}']")
      assert has_element?(lv, "#section-editor", "Text and image")
      assert has_element?(lv, "#section-editor #section-done[phx-click='close_section']")
    end

    test "edits the section it's handed next" do
      hero = hd(Pages.page_for("/").sections)
      text_media = section_of("/", :text_media)
      lv = open("/", hero.key)

      render_click(lv, "open", %{"key" => text_media.key})
      assert has_element?(lv, "#section-editor[data-section='#{text_media.key}']")

      edit_words(lv, "head.heading", "Come and see")
      assert content(text_media.key).head.heading == "Come and see"
      assert content(hero.key).heading == hero.content.value.heading
    end
  end

  describe "on the home page" do
    setup do
      home!()
      hero = hd(Pages.page_for("/").sections)
      %{lv: open("/", hero.key), hero: hero}
    end

    test "saves a field when it changes", %{lv: lv, hero: hero} do
      change(lv, %{content: %{heading: "Shop *here*"}})

      assert content(hero.key).heading == "Shop *here*"
    end

    test "turns down a bad change and saves nothing, so a bad first change makes no draft",
         %{lv: lv} do
      change(lv, %{content: %{heading: ""}})

      assert no_draft?("/")
    end

    test "the first good change makes the draft, and the live page keeps its heading",
         %{lv: lv, hero: hero} do
      change(lv, %{content: %{heading: "Draft"}})

      assert content(hero.key).heading == "Draft"
      refute hd(Pages.page_for("/").sections).content.value.heading == "Draft"
    end

    test "saves words past a soft limit", %{lv: lv, hero: hero} do
      long = String.duplicate("a", 50)
      change(lv, %{content: %{heading: long}})

      assert content(hero.key).heading == long
    end

    test "won't save words past the most a field holds", %{lv: lv} do
      change(lv, %{content: %{eyebrow: String.duplicate("a", 41)}})

      assert no_draft?("/")
    end

    test "a variant flips the photograph", %{lv: lv, hero: hero} do
      pick_variant(lv, "media_left")

      assert content(hero.key).variant == :media_left
    end

    test "only the fields the editor offers are saved", %{lv: lv, hero: hero} do
      change(lv, %{
        "content" => %{
          "_union_type" => "band",
          "heading" => "Mine",
          "bind" => "product",
          "photo" => %{"label" => "Forged", "path" => "/uploads/forged.png", "alt" => "x"}
        }
      })

      assert %{heading: "Mine", bind: :none, photo: %{label: "The shop floor", path: nil}} =
               content(hero.key)

      assert draft_section("/", hero.key).content.type == :hero
    end

    test "text only takes the photograph away", %{lv: lv, hero: hero} do
      assert has_element?(lv, "#photo-form-#{hero.key}")

      pick_variant(lv, "text_only")

      assert content(hero.key).variant == :text_only
      refute has_element?(lv, "#photo-form-#{hero.key}")
    end

    test "adds, removes, and reorders list items", %{lv: lv, hero: hero} do
      send_editor(lv, "add_item", %{"path" => "actions"})
      assert [%{kind: :link, label: "Your link"}] = content(hero.key).actions

      change(lv, %{content: %{actions: %{"0" => %{kind: "call"}}}})
      send_editor(lv, "add_item", %{"path" => "actions"})
      assert [%{kind: :call}, %{kind: :link}] = content(hero.key).actions

      send_editor(lv, "move_item", %{"path" => "actions", "index" => "1", "dir" => "up"})
      assert [%{kind: :link}, %{kind: :call}] = content(hero.key).actions

      send_editor(lv, "remove_item", %{"path" => "actions", "index" => "0"})
      assert [%{kind: :call}] = content(hero.key).actions

      send_editor(lv, "remove_item", %{"path" => "actions", "index" => "3"})
      assert [%{kind: :call}] = content(hero.key).actions

      send_editor(lv, "remove_item", %{"path" => "actions", "index" => "0"})
      assert content(hero.key).actions == []
    end

    test "stops adding at the list's limit", %{lv: lv, hero: hero} do
      for _ <- 1..4, do: send_editor(lv, "add_item", %{"path" => "actions"})

      assert length(content(hero.key).actions) == 3
    end

    test "uploads a photograph into a photo field, saving it once it arrives",
         %{lv: lv, hero: hero} do
      upload_photo(lv, hero.key, @png)

      # Described by what it shows, until Describe says more.
      assert %{path: "/uploads/" <> name, label: "The shop floor", alt: "The shop floor"} =
               content(hero.key).photo

      assert File.exists?(Path.join(Uploads.dir(), name))
    end

    test "a new photograph described only by its placeholder's words asks for better",
         %{lv: lv, hero: hero} do
      upload_photo(lv, hero.key, @png)

      # Describe opens, with its words ready to be typed over.
      assert has_element?(lv, "#section-photo input#photo-#{hero.key}_alt")

      assert_push_event(lv, "editor:focus", %{
        ids: ["photo-" <> _ | _],
        select: true
      })

      assert has_element?(
               lv,
               "#section-issues[role='status'] #section-photo-described[data-level='warning']",
               "This photograph is described by its placeholder's words."
             )

      describe_photo(lv, hero.key, %{"alt" => "Shelves of shoes by the window"})

      refute has_element?(lv, "#section-photo-described")
    end

    test "turns down a file that isn't a photograph", %{lv: lv, hero: hero} do
      upload_photo(lv, hero.key, "not a picture")

      assert has_element?(lv, "#photo-form-#{hero.key}", "not a JPEG, PNG, or WebP photograph")
      assert no_draft?("/")
    end

    test "says how a photograph on its way is getting on, and it can be called off",
         %{lv: lv, hero: hero} do
      photo =
        file_input(lv, "#photo-form-#{hero.key}", :photo, [
          %{name: "room.png", content: @png, type: "image/png"}
        ])

      render_upload(photo, "room.png", 50)
      assert has_element?(lv, "#section-photo-progress", "room.png")

      lv |> element("#section-photo-cancel") |> render_click() |> settled(lv)

      refute has_element?(lv, "#section-photo-progress")
      assert no_draft?("/")
    end

    test "a photograph on its way is called off when another section opens",
         %{lv: lv, hero: hero} do
      text_media = section_of("/", :text_media)

      photo =
        file_input(lv, "#photo-form-#{hero.key}", :photo, [
          %{name: "room.png", content: @png, type: "image/png"}
        ])

      render_upload(photo, "room.png", 50)
      render_click(lv, "open", %{"key" => text_media.key})
      render_click(lv, "open", %{"key" => hero.key})

      refute has_element?(lv, "#section-photo-progress")
      assert no_draft?("/")
    end

    test "removing a photograph keeps its file, which the live page may still show",
         %{lv: lv, hero: hero} do
      upload_photo(lv, hero.key, @png)
      "/uploads/" <> name = content(hero.key).photo.path

      send_editor(lv, "remove_photo", %{})

      assert %{path: nil, label: "The shop floor"} = content(hero.key).photo
      assert File.exists?(Path.join(Uploads.dir(), name))
    end

    test "Describe says what the photograph shows, and what it is for screen readers",
         %{lv: lv, hero: hero} do
      upload_photo(lv, hero.key, @png)
      send_editor(lv, "describe_photo", %{})

      assert has_element?(lv, "#section-photo[role='dialog']", "Describe the photograph")

      describe_photo(lv, hero.key, %{
        "label" => "The till, close",
        "alt" => "Shelves of shoes by the window"
      })

      assert %{label: "The till, close", alt: "Shelves of shoes by the window"} =
               content(hero.key).photo

      lv |> element("#section-photo-done") |> render_click()
      refute has_element?(lv, "#section-photo")
    end

    test "Describe asks for a description only once there's a photograph", %{lv: lv} do
      send_editor(lv, "describe_photo", %{})

      assert has_element?(lv, "#section-photo input[name='photo[label]']")
      refute has_element?(lv, "#section-photo input[name='photo[alt]']")
    end

    test "changes the photograph's label as it changes", %{lv: lv, hero: hero} do
      lv
      |> element("#photo-form-#{hero.key}")
      |> render_change(%{"photo" => %{"label" => "The till, close"}})
      |> settled(lv)

      assert content(hero.key).photo.label == "The till, close"
    end
  end

  describe "a section's link name" do
    test "is saved, and won't be one the site uses" do
      home!()
      text_media = section_of("/", :text_media)
      lv = open("/", text_media.key)

      change(lv, %{anchor: "dates"})
      assert draft_section("/", text_media.key).anchor == "dates"

      change(lv, %{anchor: "main"})
      assert draft_section("/", text_media.key).anchor == "dates"
    end

    test "won't be one another section has" do
      about!()
      lv = open("/about", "also-here")

      change(lv, %{anchor: "story"})

      assert no_draft?("/about")
    end
  end

  describe "a heading's optional action" do
    test "can be added and taken away" do
      home!()
      text_media = section_of("/", :text_media)
      lv = open("/", text_media.key)

      send_editor(lv, "add_part", %{"path" => "head.action"})
      assert %{kind: :link, label: "Your link"} = content(text_media.key).head.action

      send_editor(lv, "drop_part", %{"path" => "head.action"})
      assert content(text_media.key).head.action == nil
    end
  end

  describe "a part the section needs" do
    # A part whose spec leaves `optional` out is one the section needs, so
    # the editor offers no way to take it, and a forged drop changes
    # nothing.
    test "a forged drop_part on a part the section needs makes no draft" do
      about!()

      for {pattern, key, path} <- [
            {"/about", "late-opening", "quote"},
            {"/about", "whats-on", "head"},
            {nil, "promo", "quote"}
          ] do
        lv = open(pattern, key)

        send_editor(lv, "drop_part", %{"path" => path})

        assert no_draft?(pattern), "#{key} #{path}"
        assert has_element?(lv, "#section-editor[data-section='#{key}']")
      end
    end
  end

  describe "a button's popover" do
    defp edit_action(lv, path), do: send_editor(lv, "edit_action", %{"path" => path})

    # The popover's form, sent as the browser sends it. A field it doesn't
    # draw raises.
    defp change_button(lv, params),
      do: lv |> form("#section-button-form") |> render_change(params) |> settled(lv)

    test "opens on a button, with where it goes, how it looks, and its words" do
      storefront!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      edit_action(lv, "actions.1")

      assert has_element?(lv, "#section-button[role='dialog'] h2", "Button")
      assert has_element?(lv, "#section-button select[name='section[content][actions][1][kind]']")

      assert has_element?(
               lv,
               "#section-button select[name='section[content][actions][1][style]']"
             )

      assert has_element?(lv, "#section-button input[name='section[content][actions][1][label]']")
      assert has_element?(lv, "#section-button input[name='section[content][actions][1][path]']")
      assert has_element?(lv, "#section-button #section-button-remove", "Remove button")
      assert has_element?(lv, "#section-button #section-button-done", "Done")
    end

    test "saves a button's words, and leaves the others as they were" do
      storefront!()
      hero = section_of("/", :hero)
      [call, link, delivery] = hero.content.value.actions
      lv = open("/", hero.key)

      edit_action(lv, "actions.1")

      change_button(lv, %{
        "section" => %{"content" => %{"actions" => %{"1" => %{"label" => "Who we are"}}}}
      })

      assert [saved_call, saved_link, saved_delivery] = content("/", hero.key).actions

      assert {saved_link.id, saved_link.label, saved_link.path} ==
               {link.id, "Who we are", link.path}

      assert {saved_call.id, saved_call.kind} == {call.id, :call}
      assert {saved_delivery.id, saved_delivery.label} == {delivery.id, "Delivery"}
    end

    test "a change of where a button goes shows the fields that go with it" do
      storefront!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)
      edit_action(lv, "actions.1")

      change_button(lv, %{
        "section" => %{"content" => %{"actions" => %{"1" => %{"kind" => "call"}}}}
      })

      assert Enum.at(content("/", hero.key).actions, 1).kind == :call
      refute has_element?(lv, "#section-button input[name$='[label]']")
      assert has_element?(lv, "#section-button", "The site words this one itself")
    end

    test "a bad address isn't saved, and says why" do
      storefront!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)
      edit_action(lv, "actions.1")

      change_button(lv, %{
        "section" => %{"content" => %{"actions" => %{"1" => %{"path" => "our story"}}}}
      })

      assert no_draft?("/")
      assert has_element?(lv, "#section-button", "Use an address on this site, starting with /")
    end

    test "takes only a button's own fields" do
      storefront!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)
      edit_action(lv, "actions.1")

      send_editor(lv, "edit_part", %{
        "path" => "actions.1",
        "section" => %{
          "anchor" => "elsewhere",
          "content" => %{
            "heading" => "Forged",
            "actions" => %{"1" => %{"label" => "Story", "id" => "forged", "bogus" => "x"}}
          }
        }
      })

      assert %{heading: heading, actions: [_, %{label: "Story", id: id}, _]} =
               content("/", hero.key)

      assert heading == hero.content.value.heading
      assert id == Enum.at(hero.content.value.actions, 1).id
      assert draft_section("/", hero.key).anchor == hero.anchor
    end

    test "opens only on a button the section has" do
      storefront!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      for path <- ~w(actions.3 actions.-1 heading photo actions bind nowhere) do
        edit_action(lv, path)
        refute has_element?(lv, "#section-button"), path
      end
    end

    test "Done closes it" do
      storefront!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)
      edit_action(lv, "actions.0")

      lv |> element("#section-button-done") |> render_click()

      refute has_element?(lv, "#section-button")
    end

    test "Remove button takes it away, and the popover with it" do
      storefront!()
      hero = section_of("/", :hero)
      [call, _link, delivery] = hero.content.value.actions
      lv = open("/", hero.key)
      edit_action(lv, "actions.1")

      lv |> element("#section-button-remove") |> render_click() |> settled(lv)

      assert Enum.map(content("/", hero.key).actions, & &1.id) == [call.id, delivery.id]
      refute has_element?(lv, "#section-button")
    end

    test "Remove button takes away a heading's button" do
      storefront!()
      lv = open("/", "range")
      edit_action(lv, "head.action")

      assert has_element?(
               lv,
               "#section-button input[name='section[content][head][action][label]']"
             )

      lv |> element("#section-button-remove") |> render_click() |> settled(lv)

      assert content("/", "range").head.action == nil
    end

    test "adding a button puts it at the end and opens it" do
      home!()
      text_media = section_of("/", :text_media)
      lv = open("/", text_media.key)

      send_editor(lv, "add_button", %{"path" => "actions"})

      assert [%{kind: :call}, %{kind: :link, label: "Your link"}] =
               content(text_media.key).actions

      assert has_element?(lv, "#section-button input[name='section[content][actions][1][label]']")

      # Two is the most text and image takes.
      send_editor(lv, "add_button", %{"path" => "actions"})
      assert length(content(text_media.key).actions) == 2
    end

    test "adds a heading's button, and a band's" do
      home!()
      text_media = section_of("/", :text_media)
      lv = open("/", text_media.key)

      send_editor(lv, "add_button", %{"path" => "head.action"})

      assert %{kind: :link} = content(text_media.key).head.action

      assert has_element?(
               lv,
               "#section-button input[name='section[content][head][action][label]']"
             )

      band = section_of(nil, :band)
      lv = open(nil, band.key)
      send_editor(lv, "edit_action", %{"path" => "action"})
      lv |> element("#section-button-remove") |> render_click() |> settled(lv)
      assert content(nil, band.key).action == nil

      send_editor(lv, "add_button", %{"path" => "action"})
      assert %{kind: :link} = content(nil, band.key).action
    end

    test "adds only buttons" do
      about!()
      points = section_of("/about", :points)
      lv = open("/about", points.key)

      send_editor(lv, "add_button", %{"path" => "points"})
      send_editor(lv, "add_button", %{"path" => "head"})

      assert no_draft?("/about")
    end

    test "ignores a path to a point the section hasn't got" do
      about!()
      points = section_of("/about", :points)
      lv = open("/about", points.key)

      for event <- ~w(add_button add_part drop_part),
          path <- ~w(points.99.link points.-1.link points.3.link) do
        send_editor(lv, event, %{"path" => path})
      end

      assert no_draft?("/about")
      assert has_element?(lv, "#section-editor")
    end

    test "adds and takes away only what's there to add or take" do
      about!()
      lv = open("/about", "also-here")

      # Its first point has a link, and its second hasn't.
      send_editor(lv, "add_part", %{"path" => "points.0.link"})
      send_editor(lv, "drop_part", %{"path" => "points.1.link"})

      assert no_draft?("/about")
    end
  end

  describe "a point's link" do
    setup do: about!()

    test "opens in the same popover, with its words and address" do
      lv = open("/about", "also-here")

      send_editor(lv, "edit_action", %{"path" => "points.0.link"})

      assert has_element?(lv, "#section-button h2", "Link")

      assert has_element?(
               lv,
               "#section-button input[name='section[content][points][0][link][label]']"
             )

      refute has_element?(lv, "#section-button select")

      lv
      |> form("#section-button-form")
      |> render_change(%{
        "section" => %{
          "content" => %{"points" => %{"0" => %{"link" => %{"label" => "Find us"}}}}
        }
      })
      |> settled(lv)

      assert [%{link: %{label: "Find us", path: "/terms"}}, %{link: nil}] =
               content("/about", "also-here").points
    end

    test "is added to a point, and removed" do
      lv = open("/about", "also-here")

      send_editor(lv, "add_button", %{"path" => "points.1.link"})

      assert %{label: "Your link", path: "/"} =
               Enum.at(content("/about", "also-here").points, 1).link

      assert has_element?(lv, "#section-button-remove", "Remove link")

      lv |> element("#section-button-remove") |> render_click() |> settled(lv)

      assert Enum.at(content("/about", "also-here").points, 1).link == nil
    end
  end

  describe "a detail's scope" do
    setup do: item!()

    defp set_scope(lv, index, scope) do
      send_editor(lv, "edit_part", %{
        "path" => "items.#{index}",
        "section" => %{"content" => %{"items" => %{"#{index}" => %{"only_for_group" => scope}}}}
      })
    end

    test "saves on its own, leaving the other details as they were" do
      details = section_of("/items/:slug", :details)
      lv = open("/items/:slug", details.key)

      set_scope(lv, 0, "shoes")

      assert [first, second, third] = content("/items/:slug", details.key).items
      assert first.only_for_group == "shoes"
      assert {second.label, second.only_for_group} == {"Sizing", "socks"}
      assert third.label == "Returns"

      set_scope(lv, 0, "")

      assert hd(content("/items/:slug", details.key).items).only_for_group == nil
    end

    test "is one of the aisles, or the one it has" do
      details = section_of("/items/:slug", :details)
      lv = open("/items/:slug", details.key)

      # No such aisle.
      set_scope(lv, 0, "forged")
      assert no_draft?("/items/:slug")

      # Socks aren't an aisle now, but it's the one the sizing has.
      set_scope(lv, 1, "socks")
      assert hd(content("/items/:slug", details.key).items).only_for_group == nil
    end
  end

  describe "on a page that has never been committed" do
    # The home page's starter has an action in a list (the hero's), and the
    # library's band has one of its own. The editor's form is built from one
    # starter, and the draft is copied from another, so this proves the two
    # agree.
    defp action_fields(action), do: Map.take(action, [:id, :kind, :style, :label, :path])

    setup do
      assert no_draft?("/")
      assert no_draft?(nil)
      :ok
    end

    test "the hero's actions keep their ids" do
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      change(lv, %{content: %{lede: "Come in."}})

      assert %{lede: "Come in.", actions: [_] = actions} = content("/", hero.key)

      assert Enum.map(actions, &action_fields/1) ==
               Enum.map(hero.content.value.actions, &action_fields/1)

      refute has_element?(lv, "#section-refused")
    end

    test "a band's action stays as it was" do
      band = section_of(nil, :band)
      lv = open(nil, band.key)

      change(lv, %{content: %{heading: "Come and visit"}})

      assert %{heading: "Come and visit", action: action} = content(nil, band.key)
      assert action_fields(action) == action_fields(band.content.value.action)
    end

    test "a list's items move, go, and arrive by id" do
      hero = section_of("/", :hero)
      lv = open("/", hero.key)
      [shop_now] = Enum.map(hero.content.value.actions, & &1.id)

      send_editor(lv, "add_item", %{"path" => "actions"})
      assert [^shop_now, new] = Enum.map(content("/", hero.key).actions, & &1.id)
      assert new

      send_editor(lv, "move_item", %{"path" => "actions", "index" => "1", "dir" => "up"})
      assert Enum.map(content("/", hero.key).actions, & &1.id) == [new, shop_now]

      send_editor(lv, "remove_item", %{"path" => "actions", "index" => "0"})
      assert Enum.map(content("/", hero.key).actions, & &1.id) == [shop_now]
    end
  end

  describe "fields by component" do
    test "points choose their columns, and a point's link can be added" do
      about!()
      lv = open("/about", "story")

      change(lv, %{content: %{columns: "2"}})
      assert content("/about", "story").columns == 2

      send_editor(lv, "add_part", %{"path" => "points.0.link"})
      assert %{label: "Your link", path: "/"} = hd(content("/about", "story").points).link
    end

    test "two columns and each of its columns edit on their own" do
      about!()
      [left, _right] = section_of("/about", :columns).children
      lv = open("/about", "visit")

      pick_variant(lv, "wide_left")
      assert content("/about", "visit").variant == :wide_left

      render_click(lv, "open", %{"key" => left.key})
      assert has_element?(lv, "#section-editor[data-section='#{left.key}']")
      assert has_element?(lv, "#section-open-columns")

      change(lv, %{content: %{width: "narrow"}})
      assert content("/about", left.key).width == :narrow
    end

    test "a band switched to a quote gets a quote to write over" do
      band = section_of(nil, :band)
      lv = open(nil, band.key)

      pick_variant(lv, "quote_right")

      assert %{variant: :quote_right, quote: %{body: "Your quote"}} = content(nil, band.key)
    end

    test "a band that leads with its heading takes no words for the quote it keeps" do
      band = section_of(nil, :band)
      lv = open(nil, band.key)

      pick_variant(lv, "quote_right")
      pick_variant(lv, "heading")
      assert %{variant: :heading, quote: %{body: "Your quote"}} = kept = content(nil, band.key)

      edit_words(lv, "quote.body", "Forged quote")

      assert content(nil, band.key) == kept
    end
  end

  describe "words typed in place" do
    test "save a heading's words" do
      home!()
      text_media = section_of("/", :text_media)
      lv = open("/", text_media.key)

      edit_words(lv, "head.heading", "Shop with *us*")

      assert content(text_media.key).head.heading == "Shop with *us*"
      refute_push_event(lv, "words:refused", _payload)
    end

    test "save one point's words and leave the others" do
      about!()
      points = Pages.page_for("/about").sections |> Enum.find(&(&1.key == "story"))
      lv = open("/about", "story")
      [first, second, third] = points.content.value.points

      edit_words(lv, "points.1.body", "Open late on *Thursdays*.")

      assert [saved_first, saved_second, saved_third] = content("/about", "story").points
      assert saved_second.body == "Open late on *Thursdays*."
      assert {saved_second.id, saved_second.title} == {second.id, second.title}
      assert Map.take(saved_first, [:id, :title, :body]) == Map.take(first, [:id, :title, :body])
      assert Map.take(saved_third, [:id, :title, :body]) == Map.take(third, [:id, :title, :body])
    end

    test "keep a point's link" do
      about!()
      lv = open("/about", "story")
      send_editor(lv, "add_part", %{"path" => "points.0.link"})

      edit_words(lv, "points.0.body", "Linked words.")
      edit_words(lv, "points.1.body", "Other words.")

      assert [%{body: "Linked words.", link: link}, %{body: "Other words."} | _] =
               content("/about", "story").points

      assert %{label: "Your link", path: "/"} = link
    end

    test "a path to a point that isn't there changes nothing" do
      about!()
      lv = open("/about", "story")

      edit_words(lv, "points.3.body", "Nowhere")
      edit_words(lv, "points.99.body", "Nowhere")
      edit_words(lv, "points.-1.body", "Nowhere")
      edit_words(lv, "points.one.body", "Nowhere")

      assert no_draft?("/about")
    end

    test "a path to anything but words changes nothing" do
      home!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      edit_words(lv, "variant", "text_only")
      edit_words(lv, "bind", "product")
      edit_words(lv, "photo.path", "/uploads/forged.png")
      edit_words(lv, "nothing", "at all")

      assert no_draft?("/")
    end

    test "emptying a hero's heading saves nothing and says why" do
      home!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      edit_words(lv, "heading", "")

      assert no_draft?("/")

      assert_push_event(lv, "words:refused", %{
        section: key,
        path: "heading",
        text: "",
        message: "Add a heading."
      })

      assert key == hero.key
    end

    test "a refusal carries the words exactly as they were sent" do
      home!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)
      sent = "  \n  "

      edit_words(lv, "heading", sent)

      assert_push_event(lv, "words:refused", %{path: "heading", text: ^sent})
      assert no_draft?("/")
    end

    test "while a field is turned down, other words save on their own" do
      home!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      edit_words(lv, "heading", "")
      assert_push_event(lv, "words:refused", %{path: "heading"})

      edit_words(lv, "lede", "Come and look.")

      refute_push_event(lv, "words:refused", %{path: "lede"})
      assert %{heading: heading, lede: "Come and look."} = content(hero.key)
      assert heading == hero.content.value.heading
    end

    test "while words are turned down, a control's change still saves" do
      home!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      edit_words(lv, "heading", "")
      pick_variant(lv, "media_left")

      assert %{variant: :media_left, heading: heading} = content(hero.key)
      assert heading == hero.content.value.heading
    end

    test "while a control's change is turned down, words wait for it, and say so" do
      home!()
      text_media = section_of("/", :text_media)
      lv = open("/", text_media.key)

      change(lv, %{anchor: "main"})
      edit_words(lv, "head.heading", "Come and see")

      assert_push_event(lv, "words:refused", %{
        path: "head.heading",
        message: "Not saved yet. First fix the Link name."
      })

      assert has_element?(
               lv,
               "#words-#{text_media.key}-head-heading-refused",
               "Heading: Not saved yet. First fix the Link name."
             )

      assert no_draft?("/")
    end

    test "says why words didn't save until they do" do
      home!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)
      refusal = "#words-#{hero.key}-heading-refused"

      edit_words(lv, "heading", "")
      assert has_element?(lv, refusal, "Add a heading.")

      edit_words(lv, "lede", "Come and look.")
      assert has_element?(lv, refusal)

      edit_words(lv, "heading", "Look here")
      refute has_element?(lv, refusal)
      assert content(hero.key).heading == "Look here"
    end

    test "forgets why words didn't save when another section opens" do
      home!()
      hero = section_of("/", :hero)
      text_media = section_of("/", :text_media)
      lv = open("/", hero.key)

      edit_words(lv, "heading", "")
      assert has_element?(lv, "#section-issues #words-#{hero.key}-heading-refused")

      render_click(lv, "open", %{"key" => text_media.key})
      refute has_element?(lv, "#section-issues")
    end

    test "say why in plain words" do
      home!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      edit_words(lv, "eyebrow", String.duplicate("a", 41))

      assert_push_event(lv, "words:refused", %{
        path: "eyebrow",
        message: "Keep this to 40 characters or fewer."
      })

      assert has_element?(
               lv,
               "#section-issues[role='alert'] #words-#{hero.key}-eyebrow-refused",
               "Eyebrow: Keep this to 40 characters or fewer."
             )
    end

    test "waiting on a control's change are sent again once it saves" do
      home!()
      text_media = section_of("/", :text_media)
      lv = open("/", text_media.key)

      change(lv, %{anchor: "main"})
      edit_words(lv, "head.heading", "Come and see")
      assert_push_event(lv, "words:refused", %{path: "head.heading"})
      refute_push_event(lv, "words:retry", _payload)

      change(lv, %{anchor: "dates"})

      assert_push_event(lv, "words:retry", %{section: key, paths: ["head.heading"]})
      assert key == text_media.key
      refute has_element?(lv, "#words-#{text_media.key}-head-heading-refused")
    end

    test "turned down on their own aren't sent again when a control saves" do
      home!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      edit_words(lv, "heading", "")
      pick_variant(lv, "media_left")

      refute_push_event(lv, "words:retry", _payload)
      assert has_element?(lv, "#words-#{hero.key}-heading-refused")
    end

    test "a payload that isn't a path and words changes nothing" do
      home!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      send_editor(lv, "edit_words", %{"path" => "heading"})
      send_editor(lv, "edit_words", %{"path" => ["heading"], "text" => "Mine"})
      send_editor(lv, "edit_words", %{"text" => "Mine"})

      assert no_draft?("/")
      assert has_element?(lv, "#section-editor")
    end
  end

  describe "the controls header" do
    # The header's form, sent as the browser sends it: every control it
    # draws, with `params` changed. A control it doesn't draw raises.
    defp change_header(lv, params),
      do: lv |> form("#section-settings") |> render_change(params) |> settled(lv)

    test "lays out text and image three ways, with More for its link name" do
      home!()
      text_media = section_of("/", :text_media)
      lv = open("/", text_media.key)

      for {variant, words} <- [
            text_only: "No photo",
            media_left: "Photo left",
            media_right: "Photo right"
          ] do
        assert has_element?(lv, "#section-layout label", words)
        assert has_element?(lv, "#section-layout input[name='variant'][value='#{variant}']")
      end

      assert has_element?(lv, "#section-layout input[value='text_only'][checked]")
      assert has_element?(lv, "#section-more input[name='section[anchor]']")
      refute has_element?(lv, "#section-more input[name^='section[content]']")
      refute has_element?(lv, "#section-settings select")
      assert has_element?(lv, "#section-controls #section-done")
    end

    test "names the section, and its form can't take a section's DOM id" do
      home!()
      text_media = section_of("/", :text_media)
      lv = open("/", text_media.key)

      assert has_element?(lv, "#section-controls[tabindex='-1']", "Text and image")
      refute has_element?(lv, "#section-#{text_media.key}")
    end

    test "a layout saves as it's picked" do
      home!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      change_header(lv, %{"variant" => "media_left"})

      assert content(hero.key).variant == :media_left
      assert has_element?(lv, "#section-layout input[value='media_left'][checked]")
    end

    test "the hero picks its heading's size, and has no link name" do
      home!()
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      for size <- ~w(auto display h1),
          do: assert(has_element?(lv, "input[name='section[content][size]'][value='#{size}']"))

      assert has_element?(lv, "#section-setting-size[role='radiogroup'] label", "Large")

      change_header(lv, %{"section" => %{"content" => %{"size" => "display"}}})

      assert content(hero.key).size == :display
      refute has_element?(lv, "#section-more")
      # Its buttons are added where they're drawn.
      refute has_element?(lv, "#section-add-actions")
    end

    test "a bound hero says where its words come from" do
      item!()
      hero = section_of("/items/:slug", :hero)
      lv = open("/items/:slug", hero.key)

      assert has_element?(lv, "#section-note", "The heading comes from the product.")
      assert has_element?(lv, "#section-note a[href='/admin/products']")
    end

    test "a hero bound to a visit says nothing about its words" do
      visit!()
      hero = section_of("/terms", :hero)
      lv = open("/terms", hero.key)

      refute has_element?(lv, "#section-note")
    end

    test "a hero bound to a product takes no words where the product's go" do
      item!()
      hero = section_of("/items/:slug", :hero)
      lv = open("/items/:slug", hero.key)

      for field <- ~w(eyebrow heading lede), do: edit_words(lv, field, "Forged")

      assert no_draft?("/items/:slug")
    end

    test "a hero bound to a visit takes its own words" do
      visit!()
      hero = section_of("/terms", :hero)
      lv = open("/terms", hero.key)

      edit_words(lv, "heading", "Forged")

      assert content("/terms", hero.key).heading == "Forged"
    end

    test "a setting's change saves" do
      about!()
      lv = open("/about", "also-here")

      change_header(lv, %{"section" => %{"content" => %{"columns" => "3"}}})

      assert content("/about", "also-here").columns == 3
    end

    test "More holds the words a visitor sees only now and then, and they save" do
      about!()
      lv = open("/about", "whats-on")

      assert has_element?(lv, "#section-more label", "When there's no news")

      change_header(lv, %{"section" => %{"content" => %{"empty" => "Nothing on just now."}}})

      assert content("/about", "whats-on").empty == "Nothing on just now."
    end

    test "More's link name saves, and a bad one says why in plain words" do
      home!()
      text_media = section_of("/", :text_media)
      lv = open("/", text_media.key)

      change_header(lv, %{"section" => %{"anchor" => "Not OK"}})

      assert has_element?(
               lv,
               "#section-issues #section-error-anchor",
               "Link name: Use lowercase letters, numbers, and dashes"
             )

      # More says so too, in the same words.
      assert has_element?(lv, "#section-more", "Use lowercase letters, numbers, and dashes")
      refute has_element?(lv, "#section-more", "must match")

      assert has_element?(
               lv,
               "input[name='section[anchor]'][aria-invalid='true'][aria-errormessage='section-error-anchor']"
             )

      assert no_draft?("/")

      change_header(lv, %{"section" => %{"anchor" => "dates"}})

      assert draft_section("/", text_media.key).anchor == "dates"
      refute has_element?(lv, "#section-issues")
    end

    test "More's link name hint names the site's example page" do
      home!()
      lv = open("/", section_of("/", :text_media).key)

      assert has_element?(lv, "#section-more", "For links like /about#team.")
    end

    test "a setting's change keeps a heading and points the form was handed" do
      about!()
      lv = open("/about", "story")

      # Turned down, so the form holds the params it was handed, the points
      # among them, and the add with them.
      change_header(lv, %{"section" => %{"anchor" => "main"}})
      lv |> element("#section-add-head") |> render_click() |> settled(lv)
      assert no_draft?("/about")

      change_header(lv, %{
        "section" => %{"anchor" => "our-story", "content" => %{"columns" => "2"}}
      })

      assert %{columns: 2, head: %{heading: "Your heading"}, points: [_, _, _]} =
               content("/about", "story")

      change_header(lv, %{"section" => %{"content" => %{"columns" => "3"}}})

      assert %{columns: 3, head: %{heading: "Your heading"}, points: [_, _, _]} =
               content("/about", "story")
    end

    test "adds a point, up to three, where the site offers three" do
      about!()
      put_shop!(options: [points: [points: 1..3]])
      lv = open("/about", "also-here")

      lv |> element("#section-add-points", "Add a point") |> render_click() |> settled(lv)

      assert length(content("/about", "also-here").points) == 3
      refute has_element?(lv, "#section-add-points")
    end

    test "adds a point, up to four" do
      about!()
      lv = open("/about", "also-here")

      lv |> element("#section-add-points", "Add a point") |> render_click() |> settled(lv)
      assert length(content("/about", "also-here").points) == 3

      lv |> element("#section-add-points", "Add a point") |> render_click() |> settled(lv)
      assert length(content("/about", "also-here").points) == 4
      refute has_element?(lv, "#section-add-points")
    end

    test "offers Points only the columns the site does" do
      about!()
      put_shop!(options: [points: [columns: [3, 2]]])
      lv = open("/about", "also-here")

      assert has_element?(lv, "#section-setting-columns input[value='2']")
      assert has_element?(lv, "#section-setting-columns input[value='3']")
      refute has_element?(lv, "#section-setting-columns input[value='4']")

      put_shop!(options: [])
      lv = open("/about", "also-here")

      assert has_element?(lv, "#section-setting-columns label", "Four")
    end

    test "draws no layouts where the site offers only one" do
      home!()
      put_shop!(options: [hero: [variant: [:text_only]]])
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      refute has_element?(lv, "#section-layout")
    end

    test "draws only the layouts the site offers" do
      home!()
      put_shop!(options: [hero: [variant: [:media_right, :text_only]]])
      hero = section_of("/", :hero)
      lv = open("/", hero.key)

      assert has_element?(lv, "#section-layout input[value='text_only']")
      assert has_element?(lv, "#section-layout input[value='media_right']")
      refute has_element?(lv, "#section-layout input[value='media_left']")
    end

    test "takes the focus into a new point's words, selected to be typed over" do
      about!()
      lv = open("/about", "also-here")

      lv |> element("#section-add-points", "Add a point") |> render_click() |> settled(lv)

      assert_push_event(lv, "editor:focus", %{words: "also-here", at: "points-2", select: true})
    end

    test "adds a heading a section can do without, and takes it away" do
      about!()
      lv = open("/about", "story")
      refute has_element?(lv, "#section-drop-head")

      lv |> element("#section-add-head", "Add a heading") |> render_click() |> settled(lv)
      assert %{heading: "Your heading"} = content("/about", "story").head
      refute has_element?(lv, "#section-add-head")

      lv |> element("#section-more #section-drop-head") |> render_click() |> settled(lv)
      assert content("/about", "story").head == nil
    end

    test "a heading every section of its kind has can't be added or taken" do
      about!()
      lv = open("/about", "whats-on")

      refute has_element?(lv, "#section-add-head")
      refute has_element?(lv, "#section-drop-head")
    end

    test "lists the issues it's handed" do
      home!()
      lv = open("/", "welcome")
      refute has_element?(lv, "#section-issues")

      render_click(lv, "issues", %{
        "issues" => [
          %{"level" => "error", "message" => "bands can't touch"},
          %{"level" => "warning", "message" => "still says “Your heading”"}
        ]
      })

      assert has_element?(
               lv,
               "#section-issues[role='alert'] [data-level='error']",
               "Bands can't touch."
             )

      assert has_element?(lv, "#section-issues [data-level='warning']", "Still says")

      render_click(lv, "issues", %{
        "issues" => [%{"level" => "warning", "message" => "still says “Your heading”"}]
      })

      assert has_element?(lv, "#section-issues[role='status'] [data-level='warning']")
    end
  end

  describe "a Shared section" do
    test "links to the library with it open, by the editor's address" do
      about!()
      lv = open("/about", "promo-here")

      assert has_element?(
               lv,
               "#section-edit-in-library[href='/pages?open=promo&page=shared']",
               "Edit in library"
             )
    end
  end

  describe "the ground" do
    # Widening the offer changes application env, which every test that
    # saves a section reads through `Billboard.Section.Validations.SurfaceOffered`.
    # This module isn't async, so no other test sees it, and each test puts
    # it back, through `put_shop!/1`.
    #
    # A shop of its own surfaces, offering `page` to page sections and
    # `stand_out` to bands. A site that names its surfaces names every
    # offer it makes.
    defp offer(page, stand_out \\ ["loud"]) do
      put_shop!(
        surfaces: [
          %{name: "plain", label: "Plain"},
          %{name: "linen", label: "Linen"},
          %{name: "mist", label: "Mist"},
          %{name: "loud", label: "Loud"}
        ],
        offered: [page: page, stand_out: stand_out, card: []]
      )
    end

    defp ground?(lv), do: has_element?(lv, "#section-setting-surface")

    setup do: about!()

    test "offers a Points section the page's surfaces, before its own settings" do
      offer(["plain", "linen"])
      lv = open("/about", "also-here")

      assert has_element?(lv, "#section-setting-surface[role='radiogroup']", "Ground")
      assert has_element?(lv, "#section-setting-surface label", "Plain")
      assert has_element?(lv, "#section-setting-surface label", "Linen")

      assert has_element?(
               lv,
               "#section-setting-surface input[name='section[surface]'][value='plain'][checked]"
             )

      assert has_element?(lv, "#section-setting-surface ~ #section-setting-columns")
      refute has_element?(lv, "[name='section[content][surface]']")
    end

    test "saves the surface chosen, and leaves the content as it was" do
      offer(["plain", "linen"])
      points = section_of("/about", :points)
      lv = open("/about", points.key)

      change_header(lv, %{
        "section" => %{"surface" => "linen"},
        "_target" => ["section", "surface"]
      })

      saved = draft_section("/about", points.key)
      assert saved.surface == "linen"
      assert saved.content.value.columns == points.content.value.columns
      assert saved.content.value.head == points.content.value.head

      assert Enum.map(saved.content.value.points, &{&1.title, &1.body, &1.link}) ==
               Enum.map(points.content.value.points, &{&1.title, &1.body, &1.link})

      assert has_element?(lv, "#section-setting-surface input[value='linen'][checked]")
    end

    test "another setting's change leaves a surface chosen elsewhere alone" do
      offer(["plain", "linen"])
      lv = open("/about", "also-here")
      change_header(lv, %{"section" => %{"content" => %{"columns" => "3"}}})

      # Another admin chooses Linen, and this editor is handed the section
      # again, before its browser has drawn the header anew.
      assert {:ok, _saved} =
               Pages.change_draft(
                 "/about",
                 fn _draft, sections ->
                   sections
                   |> Map.fetch!("also-here")
                   |> AshPhoenix.Form.for_update(:update, actor: admin(), as: "section")
                   |> AshPhoenix.Form.submit(params: %{"surface" => "linen"})
                 end,
                 actor: admin()
               )

      render_click(lv, "open", %{"key" => "also-here"})

      # The browser still shows Plain chosen, and sends it with a change to
      # another setting.
      change(lv, %{
        "surface" => "plain",
        "content" => %{"columns" => "2"},
        "_target" => ["section", "content", "columns"]
      })

      saved = draft_section("/about", "also-here")
      assert saved.content.value.columns == 2
      assert saved.surface == "linen"
    end

    test "with more than three surfaces, Ground is a menu" do
      offer(["plain", "linen", "mist", "loud"])
      lv = open("/about", "also-here")

      assert has_element?(lv, "#section-setting-surface select[name='section[surface]']")
      assert has_element?(lv, "#section-setting-surface option[value='mist']", "Mist")
      assert has_element?(lv, "#section-setting-surface option[value='plain'][selected]")
    end

    test "isn't there with the shop's own surfaces, one of each kind" do
      lv = open("/about", "also-here")
      refute ground?(lv)
      refute has_element?(lv, "[name='section[surface]']")
      refute ground?(open("/about", "late-opening"))
    end

    test "isn't there for a section that takes its surface from elsewhere" do
      offer(["plain", "linen"])
      columns = section_of("/about", :columns)
      [column | _] = columns.children

      assert ground?(open("/about", columns.key))
      refute ground?(open("/about", column.key))
      refute ground?(open("/about", section_of("/about", :shared).key))
      refute ground?(open("/about", section_of("/about", :hero).key))
    end

    test "a surface sent to a section the header offers none saves nothing" do
      offer(["plain", "linen"])
      [column | _] = section_of("/about", :columns).children
      lv = open("/about", column.key)

      send_editor(lv, "change", %{
        "section" => %{"surface" => "linen"},
        "_target" => ["section", "surface"]
      })

      assert draft_section("/about", column.key).surface == nil
    end

    test "a surface no longer offered shows the default chosen, and another setting saves" do
      offer(["plain", "linen"])
      lv = open("/about", "also-here")

      change_header(lv, %{
        "section" => %{"surface" => "linen"},
        "_target" => ["section", "surface"]
      })

      offer(["plain", "mist"])
      lv = open("/about", "also-here")

      assert has_element?(lv, "#section-setting-surface input[value='plain'][checked]")
      refute has_element?(lv, "#section-setting-surface input[value='linen']")

      change_header(lv, %{"section" => %{"content" => %{"columns" => "3"}}})

      saved = draft_section("/about", "also-here")
      assert saved.content.value.columns == 3
      # The header sent the default it showed, which nobody chose, so the
      # section keeps what it names, and is drawn on the default.
      assert saved.surface == "linen"
    end
  end

  describe "Points' look, and its cards' grounds" do
    # Narrowing the options and widening the surfaces changes application
    # env, which every test that saves a section reads through the change
    # billboard adds to every component. This module isn't async, so no
    # other test sees it, and each test puts it back, through `put_shop!/1`.
    #
    # A shop that offers the cards look, and its surfaces to cards.
    defp offer_cards(card \\ ["plain", "loud"]) do
      put_shop!(options: [points: [look: [:rows, :cards]]])
      put_shop!(offered: [page: ["plain"], stand_out: ["loud"], card: card])
    end

    defp points_content, do: content("/about", "also-here")

    # A card's Ground, sent as its select sends it: LiveView names the
    # select in `_target`.
    defp choose_ground(lv, index, surface, target \\ :own) do
      field = ["section", "content", "points", "#{index}", "surface"]

      send_editor(
        lv,
        "edit_part",
        %{
          "path" => "points.#{index}",
          "section" => %{"content" => %{"points" => %{"#{index}" => %{"surface" => surface}}}}
        }
        |> Map.merge(if(target == :own, do: %{"_target" => field}, else: target))
      )
    end

    defp in_cards do
      lv = open("/about", "also-here")

      lv
      |> form("#section-settings")
      |> render_change(%{"section" => %{"content" => %{"look" => "cards"}}})
      |> settled(lv)

      assert points_content().look == :cards
      lv
    end

    setup do: about!()

    test "isn't offered where the site offers only rows, and a forged look saves nothing" do
      put_shop!(options: [points: [look: [:rows]]])
      lv = open("/about", "also-here")

      refute has_element?(lv, "#section-setting-look")
      refute has_element?(lv, "[name='section[content][look]']")
      assert has_element?(lv, "#section-setting-columns")

      change(lv, %{"content" => %{"look" => "cards"}})
      assert no_draft?("/about")
    end

    test "Look is a setting where the site offers cards, and saves" do
      offer_cards()
      lv = open("/about", "also-here")

      assert has_element?(lv, "#section-setting-look[role='radiogroup']", "Look")
      assert has_element?(lv, "#section-setting-look label", "Rows")
      assert has_element?(lv, "#section-setting-look label", "Cards")
      assert has_element?(lv, "#section-setting-look input[value='rows'][checked]")

      lv
      |> form("#section-settings")
      |> render_change(%{"section" => %{"content" => %{"look" => "cards"}}})
      |> settled(lv)

      assert points_content().look == :cards
      assert has_element?(lv, "#section-setting-look input[value='cards'][checked]")
    end

    test "a card's Ground saves its surface, and leaves the other points alone" do
      offer_cards()
      lv = in_cards()
      before = points_content().points

      choose_ground(lv, 1, "loud")

      assert [first, second] = points_content().points
      assert second.surface == "loud"
      assert {first.title, first.link, first.surface} == {hd(before).title, hd(before).link, nil}
      assert second.title == Enum.at(before, 1).title

      choose_ground(lv, 1, "")
      assert Enum.at(points_content().points, 1).surface == nil
    end

    test "a card's surface saves only when its Ground is what changed" do
      offer_cards()
      lv = in_cards()

      choose_ground(lv, 0, "loud", %{})
      choose_ground(lv, 0, "loud", %{"_target" => ["section", "content", "points", "0", "title"]})

      choose_ground(lv, 0, "loud", %{
        "_target" => ["section", "content", "points", "1", "surface"]
      })

      assert Enum.map(points_content().points, & &1.surface) == [nil, nil]
    end

    test "the header's change saves no card's surface, though it sends one" do
      offer_cards()
      lv = in_cards()

      # The header sends no points of its own, so a change that carries
      # them names each in full, as the form would, with one's surface.
      points =
        points_content().points
        |> Enum.with_index()
        |> Map.new(fn {point, i} -> {"#{i}", %{"id" => point.id, "title" => point.title}} end)
        |> put_in(["0", "surface"], "loud")

      send_editor(lv, "change", %{
        "section" => %{"content" => %{"look" => "rows", "points" => points}},
        "_target" => ["section", "content", "look"]
      })

      saved = points_content()
      assert saved.look == :rows
      assert Enum.map(saved.points, & &1.surface) == [nil, nil]
    end

    test "a surface the site doesn't offer cards saves nothing" do
      offer_cards()
      lv = in_cards()

      choose_ground(lv, 0, "lilac")
      assert Enum.map(points_content().points, & &1.surface) == [nil, nil]

      offer_cards([])
      lv = open("/about", "also-here")
      choose_ground(lv, 0, "loud")
      assert Enum.map(points_content().points, & &1.surface) == [nil, nil]
    end

    test "a card and a look the site has stopped offering are kept as other changes save" do
      offer_cards()
      lv = in_cards()
      choose_ground(lv, 1, "loud")

      offer_cards(["plain"])
      lv = open("/about", "also-here")
      edit_words(lv, "points.1.title", "Quieter still")

      assert [_, %{title: "Quieter still", surface: "loud"}] = points_content().points

      put_shop!(options: [points: [look: [:rows]]])
      lv = open("/about", "also-here")
      refute has_element?(lv, "#section-setting-look")
      change(lv, %{"content" => %{"columns" => "3"}})

      saved = points_content()
      assert {saved.columns, saved.look} == {3, :cards}
    end
  end
end
