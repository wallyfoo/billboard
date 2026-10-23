defmodule Billboard.SiteDslTest do
  @moduledoc "`use Billboard.Site`: its answers, its pages, its overrides, and its checks."
  # Overrides are application env, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env
  import Spark.Test

  alias Billboard.Directory.Page
  alias Billboard.Test.{Banner, Cards, Note}

  defmodule Plain do
    @moduledoc "A site with every answer a component-only site gives, and its pages."
    use Billboard.Site,
      otp_app: :billboard,
      components: [Billboard.Test.Banner, Billboard.Test.Cards, Billboard.Test.Note],
      surfaces: [%{name: "plain", label: "Plain"}, %{name: "loud", label: "Loud"}],
      offered: [page: ["plain"], stand_out: ["loud"], card: []],
      options: [cards: [look: [:rows], items: 1..3]],
      reserved_ids: [ids: ~w(shop-header), prefixes: ~w(item-)]

    pages do
      page "/", "Home", kind: :free, title: "Everything for the shop"
      page "/terms", "Terms", kind: :fixed, fixed: [:note]
    end
  end

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

  describe "its answers" do
    test "are what it wrote, ranges and sigils included" do
      assert Plain.components() == [Banner, Cards, Note]
      assert Plain.options() == [cards: [look: [:rows], items: 1..3]]
      assert Plain.reserved_ids()[:ids] == ["shop-header"]
      assert Plain.offered() == [page: ["plain"], stand_out: ["loud"], card: []]
    end

    test "leave out what it didn't write" do
      assert Plain.rules() == []
      assert Plain.resources() == []
      assert Plain.domain() == nil
      assert Plain.repo() == nil
      assert Plain.pubsub() == nil
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
             ] = Plain.pages()
    end

    test "keep a library the site writes, where it writes it" do
      assert [%Page{pattern: nil, label: "The library", kind: :library}, %Page{pattern: "/"}] =
               Overriding.pages()
    end
  end

  describe "a test's overrides" do
    test "replace the surfaces, and then the offer is the test's whole" do
      put_env_for_test(:billboard, Plain,
        surfaces: [%{name: "bg", label: "Background"}],
        offered: [page: ["bg"]]
      )

      assert Plain.surfaces() == [%{name: "bg", label: "Background"}]
      assert Plain.offered() == [page: ["bg"]]
    end

    test "merge an offer over the site's, one kind at a time" do
      put_env_for_test(:billboard, Plain, offered: [card: ["plain"]])
      assert Plain.offered() == [page: ["plain"], stand_out: ["loud"], card: ["plain"]]
    end

    test "merge options one type, then one field, at a time" do
      put_env_for_test(:billboard, Plain, options: [cards: [look: [:cards, :rows]], note: []])
      # Keyword.merge/3 puts a field it replaces after the ones it keeps.
      assert Plain.options() == [cards: [items: 1..3, look: [:cards, :rows]], note: []]
    end

    test "replace the rules whole" do
      put_env_for_test(:billboard, Plain, rules: [Mine])
      assert Plain.rules() == [Mine]
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

    test "refuse two components with one key" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.SiteDslTest.Twice do
            use Billboard.Site,
              otp_app: :billboard,
              components: [Billboard.Test.Note, Billboard.Test.Note]
          end
        end

      assert [{_, [error]}] = errors
      assert error.message =~ "lists two components with the key :note"
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
