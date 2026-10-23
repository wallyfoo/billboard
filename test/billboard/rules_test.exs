defmodule Billboard.RulesTest do
  @moduledoc """
  The stock composition rules, and the site's run after them, checked
  against sections built in memory: the rules never touch the database.
  """
  # A site's own rules are set in application env, which every test reads.
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.{Directory, Rules}
  alias Billboard.Test.GroundRule

  defp s(type, attrs \\ %{}, children \\ []) do
    %{
      key: "#{type}-#{System.unique_integer([:positive])}",
      anchor: nil,
      surface: nil,
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, attrs)},
      children: children
    }
  end

  defp hero, do: s(:hero, %{heading: "Hi"})
  defp band, do: s(:band, %{heading: "Visit"})
  defp text, do: s(:text, %{body: "Words"})

  # The shared library, as `Billboard.Pages.shared_sections/0` gives it.
  defp lib_band, do: %{band() | key: "promo", anchor: "promo"}
  defp library, do: %{"promo" => lib_band()}

  defp messages(page, sections, shared \\ %{}),
    do: Rules.check(Directory.fetch!(page), sections, shared) |> Enum.map(&{&1.level, &1.message})

  describe "check/3" do
    test "a well-formed page has nothing to say" do
      assert messages("/", [hero(), text(), band(), text()]) == []
    end

    test "a page opens with exactly one hero" do
      assert {:error, "the page opens with its hero"} in messages("/", [text(), hero()])

      assert {:error, "the page opens with its hero"} in messages("/", [])
      assert {:error, "a page has one hero"} in messages("/", [hero(), text(), hero()])
    end

    test "the shared library has no hero, and says so once" do
      assert messages(nil, [hero()]) == [{:error, "shared sections can't include a hero"}]
    end

    test "a shared section goes on a page once, so its anchor isn't repeated" do
      first = s(:shared, %{key: "promo"})
      second = s(:shared, %{key: "promo"})

      assert [%{level: :error, key: key}] =
               Rules.check(
                 Directory.fetch!("/"),
                 [hero(), text(), first, text(), second],
                 library()
               )
               |> Enum.filter(&(&1.message == "a shared section goes on a page once"))

      assert key == second.key
    end

    test "a section can't take the anchor of a shared section on the same page" do
      clash = %{text() | anchor: "promo"}
      shared = s(:shared, %{key: "promo"})

      assert [%{level: :error, key: key}] =
               Rules.check(Directory.fetch!("/"), [hero(), clash, shared], library())
               |> Enum.filter(&(&1.message =~ "anchor"))

      assert key == clash.key

      # An anchor made from a key clashes too.
      made = %{text() | key: "promo"}
      library = %{"promo" => %{lib_band() | anchor: nil}}

      assert Enum.any?(
               messages("/", [hero(), made, shared], library),
               &match?({:error, "the shared section on this page has this anchor" <> _}, &1)
             )

      # With the shared section left off the page, the anchor is free.
      assert messages("/", [hero(), clash], library()) == []
    end

    test "a shared section that has gone is a warning" do
      assert {:warning, "this shared section is no longer in the library"} in messages(
               "/",
               [hero(), text(), s(:shared, %{key: "gone"})]
             )
    end

    test "a page holds no more of a component than its max" do
      assert {:error, "a page has at most two Band"} in messages("/", [
               hero(),
               band(),
               text(),
               band(),
               text(),
               band()
             ])
    end

    test "components only go where they belong" do
      assert {:error, "Two columns can't go on this page"} in messages("/items/:slug", [
               hero(),
               s(:columns, %{}, [text(), text()])
             ])
    end

    test "fixed pages keep their sections" do
      assert messages("/terms", [hero(), text()]) == []

      assert {:error, "this page's sections are fixed: Hero, then Text"} in messages(
               "/terms",
               [hero(), text(), text()]
             )
    end

    test "two columns hold two column-friendly sections" do
      assert messages("/", [hero(), s(:columns, %{}, [text(), text()])]) == []

      assert {:error, "two columns hold exactly two sections"} in messages("/", [
               hero(),
               s(:columns, %{}, [text()])
             ])

      assert {:error, "Band can't sit in a column"} in messages("/", [
               hero(),
               s(:columns, %{}, [text(), band()])
             ])
    end

    test "raises when a Two columns section's children aren't loaded" do
      columns = %{s(:columns) | children: %Ash.NotLoaded{field: :children, type: :relationship}}
      assert_raise ArgumentError, fn -> messages("/", [hero(), columns]) end
    end

    test "sections in columns count towards a page's limits and placement" do
      columns = s(:columns, %{}, [text(), band()])

      assert {:error, "a page has at most two Band"} in messages("/", [
               hero(),
               band(),
               band(),
               columns
             ])

      assert {:error, "Band can't go on this page"} in messages("/items/:slug", [
               hero(),
               columns
             ])
    end

    test "more than one primary action is a warning" do
      hero =
        s(:hero, %{
          heading: "Hi",
          actions: [%{label: "A", style: :primary}, %{label: "B", style: :primary}]
        })

      assert {:warning, "use one primary action per section; Hero has 2"} in messages("/", [hero])
    end

    test "a head with no action has none to count" do
      cards = s(:cards, %{head: %{title: "Ours"}, items: [%{title: "One"}]})

      assert messages("/", [hero(), cards]) == []
    end

    test "a head's action and a single action count with the rest" do
      # No shop component has either, so the hero's value is built by hand.
      hero = %{
        hero()
        | content: %Ash.Union{
            type: :hero,
            value: %{head: %{action: %{style: :primary}}, action: %{style: :primary}}
          }
      }

      assert {:warning, "use one primary action per section; Hero has 2"} in messages("/", [hero])
    end

    test "each issue names the section it is about" do
      [issue] = Rules.check(Directory.fetch!("/"), [hero(), band(), band(), last = band()], %{})

      assert issue.key == last.key
    end
  end

  describe "errors/3" do
    test "keeps only what blocks a commit" do
      page = Directory.fetch!("/")
      gone = s(:shared, %{key: "gone"})

      assert Rules.errors(page, [hero(), text(), band()], %{}) == []
      assert Rules.errors(page, [hero(), text(), gone], %{}) == []
      assert [%{level: :error}] = Rules.errors(page, [text(), hero(), gone], %{})
    end
  end

  describe "the site's rules" do
    test "are only those the site lists" do
      put_shop!(rules: [GroundRule])
      assert messages("/", [hero(), text(), band(), band()]) != []

      put_shop!(rules: [])
      assert messages("/", [hero(), text(), band(), band()]) == []
    end
  end

  describe "a site rule of the test's own" do
    # SWAN's rule, with a second stand-out surface so two bands may differ.
    setup do
      put_shop!(
        surfaces: [
          %{name: "plain", label: "Plain"},
          %{name: "loud", label: "Loud"},
          %{name: "night", label: "Night"}
        ],
        offered: [page: ["plain"], stand_out: ["loud", "night"]],
        rules: [GroundRule]
      )
    end

    @same_ground "two stand-out sections in a row can't share a ground"

    test "has its issues reported, after the stock rules'" do
      second = band()

      assert [stock, %{level: :error, key: key, message: @same_ground}] =
               Rules.check(Directory.fetch!("/"), [text(), band(), second], %{})

      assert stock.message == "the page opens with its hero"
      assert key == second.key
    end

    test "has its errors reported by errors/3" do
      second = band()
      page = Directory.fetch!("/")

      assert Rules.errors(page, [hero(), text(), band(), second, text()], %{}) == [
               %{level: :error, key: second.key, message: @same_ground}
             ]

      night = %{band() | surface: "night"}
      assert Rules.errors(page, [hero(), text(), band(), night, text()], %{}) == []
    end

    test "finds touching bands on different grounds fine" do
      night = %{band() | surface: "night"}

      assert messages("/", [hero(), band(), night, text()]) == []
    end

    test "counts no surface, or one no longer offered, as the kind's default" do
      assert {:error, @same_ground} in messages("/", [
               hero(),
               text(),
               %{band() | surface: "loud"},
               band()
             ])

      assert {:error, @same_ground} in messages("/", [
               hero(),
               text(),
               %{band() | surface: "gone"},
               band()
             ])
    end

    test "sees a Shared section as its library section, on that section's surface" do
      shared = s(:shared, %{key: "promo"})
      night_library = %{"promo" => %{lib_band() | surface: "night"}}

      assert [%{key: key, message: @same_ground}] =
               Rules.check(
                 Directory.fetch!("/"),
                 [hero(), text(), %{band() | surface: "night"}, shared],
                 night_library
               )

      assert key == shared.key

      assert messages("/", [hero(), text(), band(), shared], night_library) == []
    end
  end

  test "a site with no hero component asks for none" do
    put_site!(components: [Billboard.Test.Text])
    page = %Billboard.Directory.Page{pattern: "/", label: "Home", kind: :free}

    assert Rules.check(page, [s(:text, %{body: "Words"})], %{}) == []
  end

  describe "a component's own rules" do
    test "run on each of its sections, after the stock rules and before the site's" do
      put_site!(
        components: [Billboard.Test.Hero, Billboard.Test.Faq],
        rules: [Billboard.Test.PageNote]
      )

      page = %Billboard.Directory.Page{pattern: "/", label: "Home", kind: :free}

      faq = s(:faq, %{title: "Asked", questions: [%{question: "Open?", answer: nil}]})
      key = faq.key

      assert Rules.check(page, [faq], %{}) == [
               %{level: :error, key: key, message: "the page opens with its hero"},
               %{level: :warning, key: key, message: "a question has no answer yet"},
               %{level: :warning, key: nil, message: "a note on the page"}
             ]
    end

    test "say nothing of a section they find nothing wrong with" do
      put_site!(components: [Billboard.Test.Faq])
      page = %Billboard.Directory.Page{pattern: "/", label: "Home", kind: :free}

      faq = s(:faq, %{title: "Asked", questions: [%{question: "Open?", answer: "Yes."}]})

      assert Rules.check(page, [faq], %{}) == []
    end
  end

  describe "actions_of/1" do
    # Built by hand, since no shop component has every kind of action.
    test "gives a section's list, then its single action, then its head's action" do
      value = %{actions: [%{label: "A"}], action: %{label: "B"}, head: %{action: %{label: "C"}}}

      assert Rules.actions_of(%{content: %Ash.Union{type: :hero, value: value}}) ==
               [%{label: "A"}, %{label: "B"}, %{label: "C"}]
    end

    test "gives none for a section with no actions, or a head without one" do
      value = %{heading: "Hi", head: %{title: "Ours"}}
      assert Rules.actions_of(%{content: %Ash.Union{type: :hero, value: value}}) == []
    end
  end
end
