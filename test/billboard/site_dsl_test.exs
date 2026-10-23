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
