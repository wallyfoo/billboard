defmodule Billboard.ComponentEditorTest do
  @moduledoc "A component's `editor` section, its renderer, and whether its placeholder is filler."
  use ExUnit.Case, async: true

  import Spark.Test

  alias Billboard.Component.Info
  alias Billboard.Test.Faq

  test "reads the editor's entries in the order written, in the editor's shape" do
    assert [
             style: [as: :select, label: "Style", options: [{"Open", :open}, {"Folded", :folded}]],
             title: [accent: true, as: :text, label: "Title", limit: 60],
             note: [as: :note, text: "Answers fold on phones."],
             intro: [as: :markdown, label: "Introduction", limit: 200, more: true],
             questions: [
               as: :list,
               item_label: "question",
               max: 8,
               part: {:detail, except: [:only_for_group]}
             ]
           ] = Info.editor_fields(Faq)
  end

  test "names its renderer, and says whether its placeholder is filler" do
    assert Info.component_renderer!(Faq) == Billboard.Test.FaqRenderer
    refute Info.component_filler?(Faq)
    assert Info.component_filler?(Billboard.Test.Note)
    assert Info.editor_fields(Billboard.Test.Note) == []
  end

  test "names its renderer without depending on it at compile time" do
    {graph, 0} =
      System.cmd(
        "mix",
        ~w(xref graph --source test/support/components/faq.ex --label compile),
        env: [{"MIX_ENV", "test"}]
      )

    refute graph =~ "faq_renderer.ex"
  end

  describe "the checks" do
    test "refuse an entry that isn't an attribute, and name the fix" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.ComponentEditorTest.Typo do
            use Billboard.Component

            component do
              key :typo
              label "Typo"
              hint "x"
              category :content
            end

            editor do
              words :titel, label: "Title"
            end

            attributes do
              attribute :title, :string, public?: true
            end
          end
        end

      assert [{_, [error]}] = errors

      assert error.message =~
               "`:titel` is in `editor` but isn't an attribute of " <>
                 "Billboard.ComponentEditorTest.Typo. Add `attribute :titel, :string`, " <>
                 "or take it out of `editor`"
    end

    test "refuse words that aren't a string, a list without its part, and a choice without its set" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.ComponentEditorTest.Wrong do
            use Billboard.Component

            component do
              key :wrong
              label "Wrong"
              hint "x"
              category :content
              parts :items, Billboard.Test.Question
            end

            editor do
              words :count, label: "Count"
              field :items, as: :list
              field :aisle, as: :choice, label: "Aisle"
            end

            attributes do
              attribute :count, :integer, public?: true
              attribute :aisle, :string, public?: true
            end
          end
        end

      assert [{_, errors}] = errors
      messages = Enum.map(errors, & &1.message)
      assert Enum.any?(messages, &(&1 =~ "`:count` is words in `editor`, but it isn't a string"))
      assert Enum.any?(messages, &(&1 =~ "`:items` is a list in `editor` but names no part"))
      assert Enum.any?(messages, &(&1 =~ "`:aisle` is a choice in `editor` but names no set"))
    end

    test "refuse a second set of several choices" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.ComponentEditorTest.TwoChoices do
            use Billboard.Component

            component do
              key :two_choices
              label "Two choices"
              hint "x"
              category :content
            end

            editor do
              field :aisles, as: :choices, from: :scope, label: "Aisles"
              field :shelves, as: :choices, from: :scope, label: "Shelves"
            end

            attributes do
              attribute :aisles, {:array, :string}, public?: true, default: []
              attribute :shelves, {:array, :string}, public?: true, default: []
            end
          end
        end

      assert [{_, errors}] = errors

      assert Enum.map(errors, & &1.message) == [
               "`:shelves` is a second set of several choices in `editor`, and the editor " <>
                 "offers one a section. Make it a `:choice`, or take it out of `editor`"
             ]
    end
  end
end
