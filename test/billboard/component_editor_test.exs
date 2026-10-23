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

  test "names the context it reads, and its own rules" do
    assert Info.component_context!(Faq) == [:scope]
    assert Info.component_context!(Billboard.Test.Note) == []
    assert Info.component_rules!(Faq) == [Billboard.Test.NoQuestions]
  end

  # It shells out to `mix xref`, which takes about half a second.
  @tag :xref
  test "names its renderer and its rules without depending on them at compile time" do
    {graph, status} =
      System.cmd(
        "mix",
        ~w(xref graph --source test/support/components/faq.ex --label compile),
        env: [{"MIX_ENV", "test"}],
        stderr_to_stdout: true,
        cd: File.cwd!()
      )

    assert status == 0, graph

    refute graph =~ "faq_renderer.ex"
    refute graph =~ "no_questions.ex"
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

      assert error.message ==
               "`:titel` is in `editor` but isn't an attribute of " <>
                 "Billboard.ComponentEditorTest.Typo (did you mean `:title`?). " <>
                 "Add `attribute :titel, :string`, or take it out of `editor`"
    end

    test "suggest the attribute a missing entry needs, by what it is" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.ComponentEditorTest.Missing do
            use Billboard.Component

            component do
              key :missing
              label "Missing"
              hint "x"
              category :content
            end

            editor do
              field :head, as: :part, part: :head
              field :points, as: :list, part: :point
              field :photo, as: :photo
              field :aisles, as: :choices, from: :scope
              field :open, as: :toggle
              field :count, as: :number
              field :size, as: :select, options: [{"Small", :small}, {"Large", :large}]
              field :layout, as: :variants, options: [:wide, :narrow]
              field :aisle, as: :choice, from: :scope
            end
          end
        end

      assert [{_, errors}] = errors
      fixes = Enum.map(errors, &(&1.message |> String.split(". Add ") |> List.last()))

      assert fixes == [
               "`part :head, MySite.Parts.Name` to `component`, or take it out of `editor`",
               "`parts :points, MySite.Parts.Name` to `component`, or take it out of `editor`",
               "`part :photo, MySite.Parts.Photo` to `component`, or take it out of `editor`",
               "`attribute :aisles, {:array, :string}`, or take it out of `editor`",
               "`attribute :open, :boolean`, or take it out of `editor`",
               "`attribute :count, :integer`, or take it out of `editor`",
               "`attribute :size, :atom, constraints: [one_of: [:small, :large]]`, " <>
                 "or take it out of `editor`",
               "`attribute :layout, :atom, constraints: [one_of: [:wide, :narrow]]`, " <>
                 "or take it out of `editor`",
               "`attribute :aisle, :string`, or take it out of `editor`"
             ]
    end

    test "refuse a select with no options, and variants with no layouts" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.ComponentEditorTest.NoOptions do
            use Billboard.Component

            component do
              key :no_options
              label "No options"
              hint "x"
              category :content
            end

            editor do
              field :size, as: :select, label: "Size"
              field :variant, as: :variants
            end

            attributes do
              attribute :size, :atom, public?: true
              attribute :variant, :atom, public?: true
            end
          end
        end

      assert [{_, errors}] = errors

      assert Enum.map(errors, & &1.message) == [
               ~s|`:size` is a select in `editor` but gives no options. | <>
                 ~s|Add `options: [{"Label", :value}, …]`|,
               "`:variant` is variants in `editor` but gives no layouts. " <>
                 "Add `options: [:text_only, :media_right, …]`, its layouts in order"
             ]
    end

    test "refuse options that aren't among the attribute's values" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.ComponentEditorTest.OffList do
            use Billboard.Component

            component do
              key :off_list
              label "Off list"
              hint "x"
              category :content
            end

            editor do
              field :size,
                as: :select,
                options: [{"Small", :small}, {"Huge", :huge}, {"Tiny", :tiny}]

              field :variant, as: :variants, options: [:wide, :tall]
            end

            attributes do
              attribute :size, :atom, public?: true, constraints: [one_of: [:small, :large]]
              attribute :variant, :atom, public?: true, constraints: [one_of: [:wide, :narrow]]
            end
          end
        end

      assert [{_, errors}] = errors

      assert Enum.map(errors, & &1.message) == [
               "`:size` offers `:huge` and `:tiny` in `editor`, which aren't among its values " <>
                 "(`one_of: [:small, :large]`). Add them to its `one_of`, or take them out of " <>
                 "`options`",
               "`:variant` offers `:tall` in `editor`, which isn't among its values " <>
                 "(`one_of: [:wide, :narrow]`). Add it to its `one_of`, or take it out of " <>
                 "`options`"
             ]
    end

    test "refuse a name twice, a hide_when on no attribute, a part that isn't one, " <>
           "and choices that aren't strings" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.ComponentEditorTest.Muddled do
            use Billboard.Component

            component do
              key :muddled
              label "Muddled"
              hint "x"
              category :content
            end

            editor do
              words :title, label: "Title", hide_when: [varient: [:plain]]
              field :title, as: :select, options: [{"A", :a}]
              field :heading, as: :part, part: :head
              field :points, as: :list, part: :point
              field :aisles, as: :choices, from: :scope
            end

            attributes do
              attribute :title, :string, public?: true
              attribute :variant, :atom, public?: true
              attribute :heading, :string, public?: true
              attribute :points, {:array, :string}, public?: true
              attribute :aisles, :string, public?: true
            end
          end
        end

      assert [{_, errors}] = errors

      assert Enum.map(errors, & &1.message) == [
               "`:title` hides when `:varient` holds some values, but `:varient` isn't an " <>
                 "attribute of Billboard.ComponentEditorTest.Muddled (did you mean " <>
                 "`:variant`?). Name one of its attributes in `hide_when`, or take it out",
               "`:title` is in `editor` twice. Give each entry an attribute of its own, " <>
                 "or take one out",
               "`:heading` is a part in `editor`, but it isn't a part. Add " <>
                 "`part :heading, MySite.Parts.Name` to `component` in place of its " <>
                 "attribute, or make it another kind of entry",
               "`:points` is a list in `editor`, but it isn't a list of parts. Add " <>
                 "`parts :points, MySite.Parts.Name` to `component` in place of its " <>
                 "attribute, or make it another kind of entry",
               "`:aisles` is several choices in `editor`, but it isn't a list of strings. " <>
                 "Make it `attribute :aisles, {:array, :string}`"
             ]
    end

    test "refuse a renderer that isn't a module" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.ComponentEditorTest.Unrendered do
            use Billboard.Component

            component do
              key :unrendered
              label "Unrendered"
              hint "x"
              category :content
              renderer Billboard.ComponentEditorTest.NoSuchRenderer
            end
          end
        end

      assert [{_, [error]}] = errors

      assert error.message ==
               "`renderer` names Billboard.ComponentEditorTest.NoSuchRenderer, which isn't " <>
                 "a module. Define it, with `use Billboard.Renderer`, or name the module " <>
                 "that draws Billboard.ComponentEditorTest.Unrendered"
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
