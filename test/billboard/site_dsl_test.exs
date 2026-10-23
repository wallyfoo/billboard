defmodule Billboard.SiteDslTest do
  @moduledoc "`use Billboard.Site`: its answers, its pages, its overrides, and its checks."
  # Overrides are application env, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env
  import Spark.Test

  alias Billboard.Directory.Page
  alias Billboard.Test.{Banner, Cards, Note, PlainSite}

  defmodule Overriding do
    @moduledoc "A site that writes one callback itself, on top of what billboard defines."
    use Billboard.Site, otp_app: :billboard, components: [], rules: [Some.Rule]

    @impl Billboard.Site
    def rules, do: [Another.Rule | super()]

    pages do
      library "The library"
      page "/", "Home", kind: :free
    end
  end

  defmodule Attributes do
    @moduledoc """
    A site whose answers read its own module attributes, one of them named
    as Spark names an attribute of its own.
    """
    @opts [note: [look: [:rows]]]
    @rules [Some.Rule]

    use Billboard.Site, otp_app: :billboard, options: @opts, rules: @rules
  end

  defmodule UnsavedVersion do
    @moduledoc "Stands in for a version resource, which billboard doesn't write yet."
    defstruct [:status, sections: []]
  end

  defmodule Unsaved do
    @moduledoc "A site with no starter, whose version resource is `UnsavedVersion`."
    use Billboard.Site, otp_app: :billboard

    @impl Billboard.Site
    def resources, do: [version: UnsavedVersion]
  end

  defmodule Greeting do
    @moduledoc "A starter that says which of its functions built the version."
    @behaviour Billboard.Starter

    @impl true
    def version(pattern), do: %UnsavedVersion{status: :starter, sections: [lenient: pattern]}

    @impl true
    def version!(pattern), do: %UnsavedVersion{status: :starter, sections: [strict: pattern]}
  end

  defmodule Started do
    @moduledoc "A site with a starter."
    use Billboard.Site, otp_app: :billboard, starter: Billboard.SiteDslTest.Greeting
  end

  defmodule OtherNote do
    @moduledoc "A component that takes `Billboard.Test.Note`'s key."
    use Billboard.Component

    component do
      key :note
      label "Other note"
      hint "Another few words."
      category :paper
    end
  end

  defmodule UnnamedSets do
    @moduledoc "A context that gives a set of choices without saying which sets it gives."
    def choices(:scope), do: %{options: [], every: "All", none_yet: "None yet.", gone: "gone"}
  end

  describe "its answers" do
    test "are what it wrote, ranges and sigils included" do
      assert PlainSite.components() == [Banner, Cards, Note]
      assert PlainSite.options() == [cards: [look: [:rows], items: 1..3]]
      assert PlainSite.reserved_ids()[:ids] == ["shop-header"]
      assert PlainSite.offered() == [page: ["plain"], stand_out: ["loud"], card: []]
    end

    test "leave out what it didn't write" do
      assert PlainSite.rules() == []
      assert PlainSite.resources() == []
      assert PlainSite.domain() == nil
      assert PlainSite.repo() == nil
      assert PlainSite.pubsub() == nil
    end

    test "can read the site's own module attributes, whatever their names" do
      assert Attributes.options() == [note: [look: [:rows]]]
      assert Attributes.rules() == [Some.Rule]
    end

    test "fill in the reserved ids a site leaves out" do
      assert PlainSite.reserved_ids() == [
               ids: ["shop-header"],
               prefixes: ["item-"],
               suffixes: [],
               owned: %{}
             ]

      assert Overriding.reserved_ids() == [ids: [], prefixes: [], suffixes: [], owned: %{}]
    end

    test "can be written by the site itself, with billboard's as super" do
      assert Overriding.rules() == [Another.Rule, Some.Rule]
    end

    test "name the site's actions and context, and narrow the palette" do
      assert PlainSite.actions() == Billboard.Test.Actions
      assert PlainSite.context() == Billboard.Test.Context
      assert PlainSite.kinds() == [cards: [:free]]
      assert PlainSite.palette()[:hints] == [note: "A short note."]
      assert PlainSite.example_path() == "/terms"
    end

    test "default to links alone, no context, and the component's own kinds and words" do
      assert Overriding.actions() == nil
      assert Overriding.context() == nil
      assert Overriding.kinds() == []
      # Spark.Options may not fill a nested default the site never wrote,
      # so read it as the catalogue does.
      assert (Overriding.palette()[:hints] || []) == []
      assert Overriding.example_path() == "/about"
    end
  end

  describe "its pages" do
    test "are in the order written, with the library added last" do
      assert [
               %Page{pattern: "/", label: "Home", kind: :free, title: "Everything for the shop"},
               %Page{pattern: "/terms", kind: :fixed, fixed: [:note]},
               %Page{pattern: nil, label: "Shared sections", kind: :library}
             ] = PlainSite.pages()
    end

    test "keep a library the site writes, where it writes it" do
      assert [%Page{pattern: nil, label: "The library", kind: :library}, %Page{pattern: "/"}] =
               Overriding.pages()
    end
  end

  describe "its starter" do
    test "is the starter's, through version!/1 when the starter has one" do
      assert Started.starter("/") == %UnsavedVersion{status: :starter, sections: [lenient: "/"]}
      assert Started.starter!(nil) == %UnsavedVersion{status: :starter, sections: [strict: nil]}
    end

    # The configured site is the shop, so these show the site asked is the
    # one whose version resource is used.
    test "without one, is an empty version of the site's own version resource" do
      assert Unsaved.starter("/") == %UnsavedVersion{status: :starter, sections: []}
      assert Unsaved.starter!(nil) == %UnsavedVersion{status: :starter, sections: []}
    end

    test "without one or a version resource, raises, naming the site and the fix" do
      assert_raise ArgumentError,
                   ~r/Billboard.Test.PlainSite names no version resource. Add `version: MySite.Pages.Version` to the `resources:` of its `use Billboard.Site`/,
                   fn -> PlainSite.starter("/") end
    end
  end

  describe "a test's overrides" do
    test "replace the surfaces, and then the offer is the test's whole" do
      put_env_for_test(:billboard, PlainSite,
        surfaces: [%{name: "bg", label: "Background"}],
        offered: [page: ["bg"]]
      )

      assert PlainSite.surfaces() == [%{name: "bg", label: "Background"}]
      assert PlainSite.offered() == [page: ["bg"]]
    end

    test "merge an offer over the site's, one kind at a time" do
      put_env_for_test(:billboard, PlainSite, offered: [card: ["plain"]])
      assert PlainSite.offered() == [page: ["plain"], stand_out: ["loud"], card: ["plain"]]
    end

    test "merge options one type, then one field, at a time" do
      put_env_for_test(:billboard, PlainSite, options: [cards: [look: [:cards, :rows]], note: []])
      # Keyword.merge/3 puts a field it replaces after the ones it keeps.
      assert PlainSite.options() == [cards: [items: 1..3, look: [:cards, :rows]], note: []]
    end

    test "replace the rules whole" do
      put_env_for_test(:billboard, PlainSite, rules: [Mine])
      assert PlainSite.rules() == [Mine]
    end

    test "replace the kinds and the palette whole" do
      put_env_for_test(:billboard, PlainSite, kinds: [], palette: [categories: [paper: "Paper"]])
      assert PlainSite.kinds() == []
      assert PlainSite.palette() == [categories: [paper: "Paper"]]
    end
  end

  describe "a bad answer" do
    test "without otp_app doesn't compile, and says what to add" do
      assert_raise ArgumentError, ~r/needs `otp_app:`/, fn ->
        Code.compile_string("""
        defmodule Billboard.SiteDslTest.NoApp do
          use Billboard.Site, components: []
        end
        """)
      end
    end

    test "with an otp_app that isn't an atom doesn't compile, and says to write one" do
      assert_raise ArgumentError,
                   ~r/needs `otp_app:` as an atom, such as `otp_app: :my_site`/,
                   fn ->
                     Code.compile_string("""
                     defmodule Billboard.SiteDslTest.AppAttribute do
                       @app :billboard
                       use Billboard.Site, otp_app: @app
                     end
                     """)
                   end
    end

    test "that isn't a keyword list written in place doesn't compile, and shows one" do
      assert_raise ArgumentError, ~r/takes its answers as a keyword list written in place/, fn ->
        Code.compile_string("""
        defmodule Billboard.SiteDslTest.AnswersAttribute do
          @answers [otp_app: :billboard]
          use Billboard.Site, @answers
        end
        """)
      end
    end

    test "naming an option billboard doesn't take doesn't compile, and names the option" do
      assert_raise ArgumentError, ~r/use Billboard.Site`: unknown options \[:compnents\]/, fn ->
        Code.compile_string("""
        defmodule Billboard.SiteDslTest.Typo do
          use Billboard.Site, otp_app: :billboard, compnents: []
        end
        """)
      end
    end

    test "with a surface that isn't a name and a label doesn't compile, and shows one" do
      assert_raise ArgumentError, ~r/such as `%\{name: "paper", label: "Paper"\}`/, fn ->
        Code.compile_string("""
        defmodule Billboard.SiteDslTest.BadSurface do
          use Billboard.Site, otp_app: :billboard, surfaces: ["paper"]
        end
        """)
      end
    end
  end

  describe "the verifiers" do
    test "refuse a component that isn't one" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.NotAComponent do
            use Billboard.Site, otp_app: :billboard, components: [Billboard.Test.Plain]
          end
        end

      assert [{_, [error]}] = errors

      assert error.message =~
               "lists Billboard.Test.Plain in `components:`, which isn't a billboard component"
    end

    test "refuse a component listed twice" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.Twice do
            use Billboard.Site,
              otp_app: :billboard,
              components: [Billboard.Test.Note, Billboard.Test.Note]
          end
        end

      assert [{_, [error]}] = errors
      assert error.message =~ "lists Billboard.Test.Note twice in `components:`. Take one out."
    end

    test "refuse two components with one key" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.SharedKey do
            use Billboard.Site,
              otp_app: :billboard,
              components: [Billboard.Test.Note, Billboard.SiteDslTest.OtherNote]
          end
        end

      assert [{_, [error]}] = errors

      assert error.message =~
               "lists two components with the key :note: Billboard.Test.Note and " <>
                 "Billboard.SiteDslTest.OtherNote"
    end

    test "refuse a module that isn't a component and two components with one key, at once" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.BothWrong do
            use Billboard.Site,
              otp_app: :billboard,
              components: [
                Billboard.Test.Plain,
                Billboard.Test.Note,
                Billboard.SiteDslTest.OtherNote
              ]
          end
        end

      assert [{_, errors}] = errors
      messages = Enum.map(errors, & &1.message)
      assert Enum.any?(messages, &(&1 =~ "lists Billboard.Test.Plain in `components:`"))
      assert Enum.any?(messages, &(&1 =~ "lists two components with the key :note"))
    end

    test "refuse a page named twice, a pattern without its slash, and a fixed section the site lacks" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.BadPages do
            use Billboard.Site, otp_app: :billboard, components: [Billboard.Test.Note]

            pages do
              page "/", "Home", kind: :free
              page "/", "Home again", kind: :free
              page "terms", "Terms", kind: :free
              page "/fixed", "Fixed", kind: :fixed, fixed: [:note, :hero]
            end
          end
        end

      assert [{_, errors}] = errors
      messages = Enum.map(errors, & &1.message)
      assert Enum.any?(messages, &(&1 =~ "names the page \"/\" twice"))
      assert Enum.any?(messages, &(&1 =~ "\"terms\" doesn't start with /"))
      assert Enum.any?(messages, &(&1 =~ "fixes :hero on \"/fixed\", but lists no component"))
    end

    test "refuse kinds for a component the site doesn't list" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.StrayKinds do
            use Billboard.Site,
              otp_app: :billboard,
              components: [Billboard.Test.Note],
              kinds: [cards: [:free]]
          end
        end

      assert [{_, [error]}] = errors

      assert error.message =~ "narrows the kinds of :cards, but lists no component with that key"
    end

    test "refuse a component narrowed twice, and a page kind no page has" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.WrongKinds do
            use Billboard.Site,
              otp_app: :billboard,
              components: [Billboard.Test.Note],
              kinds: [note: [:servce], note: [:free]]

            pages do
              page "/", "Home", kind: :free
              page "/services", "Services", kind: :service
            end
          end
        end

      assert [{_, errors}] = errors

      assert Enum.map(errors, & &1.message) == [
               "Billboard.SiteDslTest.WrongKinds narrows :note twice in `kinds:`. Take one out.",
               "Billboard.SiteDslTest.WrongKinds keeps :note to the page kind :servce in " <>
                 "`kinds:`, but no page in `pages` has that kind. Use one of :free, :service, " <>
                 "and :library, or add a page of that kind."
             ]
    end

    test "leave the page kinds alone on a site that writes no pages" do
      refute_dsl_errors do
        defmodule Elixir.Billboard.SiteDslTest.NoPagesYet do
          use Billboard.Site,
            otp_app: :billboard,
            components: [Billboard.Test.Note],
            kinds: [note: [:anything]]
        end
      end
    end

    test "refuse a hint for a component the site doesn't list, and a hint given twice" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.StrayHints do
            use Billboard.Site,
              otp_app: :billboard,
              components: [Billboard.Test.Note],
              palette: [hints: [cardz: "Cards.", note: "A few words.", note: "Some words."]]
          end
        end

      assert [{_, errors}] = errors

      assert Enum.map(errors, & &1.message) == [
               "Billboard.SiteDslTest.StrayHints gives :cardz a hint in `palette: [hints: …]`, " <>
                 "but lists no component with that key. Add the component to `components:`, " <>
                 "or take :cardz out of `hints:`.",
               "Billboard.SiteDslTest.StrayHints gives :note two hints in " <>
                 "`palette: [hints: …]`. Take one out."
             ]
    end

    test "refuse actions that aren't a module, or a module without their callbacks" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.NoKinds do
            use Billboard.Site,
              otp_app: :billboard,
              components: [],
              actions: Billboard.Test.Context
          end
        end

      assert [{_, [error]}] = errors

      assert error.message =~ "doesn't define kinds/0 and action/1"

      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.NoActions do
            use Billboard.Site,
              otp_app: :billboard,
              components: [],
              actions: Billboard.SiteDslTest.Nowhere
          end
        end

      assert [{_, [error]}] = errors

      assert error.message =~
               "`actions:` is Billboard.SiteDslTest.Nowhere, which isn't a module. " <>
                 "Name its `Billboard.Actions` module."
    end

    test "refuse a context that isn't a module, or gives choices without naming them" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.NoContext do
            use Billboard.Site, otp_app: :billboard, context: Billboard.SiteDslTest.Nowhere
          end
        end

      assert [{_, [error]}] = errors

      assert error.message =~ "`context:` is Billboard.SiteDslTest.Nowhere, which isn't a module"

      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.UnnamedChoices do
            use Billboard.Site,
              otp_app: :billboard,
              context: Billboard.SiteDslTest.UnnamedSets
          end
        end

      assert [{_, [error]}] = errors

      assert error.message =~ "defines choices/1 but not choice_sets/0"
    end

    test "pass a site that keeps every rule" do
      refute_dsl_errors do
        defmodule Elixir.Billboard.SiteDslTest.Good do
          use Billboard.Site, otp_app: :billboard, components: [Billboard.Test.Note]

          pages do
            page "/", "Home", kind: :free, fixed: [:note]
          end
        end
      end
    end
  end
end
