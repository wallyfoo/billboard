defmodule Billboard.PartTest do
  @moduledoc "A site's own part: its editor entries and its blank, read as a stock part's are."
  # The site's components are set in application env, which other tests
  # read.
  use ExUnit.Case, async: false

  import Billboard.Test.Env
  import Spark.Test

  alias Billboard.Part.Info
  alias Billboard.Sections.{EditorFields, Parts}
  alias MySite.Sections.Faq.Question

  test "reads its editor entries in the editor's shape, and its blank as form params" do
    assert Info.editor_fields(Question) == [
             title: [as: :text, label: "Question", limit: 80],
             body: [as: :markdown, label: "Answer", limit: 400]
           ]

    assert Info.blank(Question) == %{"title" => "Your question"}
    assert Info.part?(Question)
    refute Info.part?(Billboard.Parts.Detail)
    refute Info.part?(String)
  end

  test "the editor reads a site's part where it reads a stock part's name" do
    assert Parts.editor_fields(Question) == Info.editor_fields(Question)

    assert Parts.editor_fields({Question, except: [:body]}) == [
             title: [as: :text, label: "Question", limit: 80]
           ]

    assert Parts.blank(Question) == %{"title" => "Your question"}
  end

  test "words in a site's part are found by their path, as a stock part's are" do
    put_site!(components: [Billboard.Test.Notes])

    assert {:ok, [:items, 0, :body], spec} =
             EditorFields.words(EditorFields.specs(:notes), "items.0.body")

    assert spec[:as] == :markdown
  end

  test "lists the site's parts its components name" do
    put_site!(components: [Billboard.Test.Notes])
    assert Parts.site_parts() == [Question]
  end

  defmodule Label do
    @moduledoc "A site's part another site's part holds."
    use Billboard.Part

    part do
      blank %{text: "Your label"}
    end

    editor do
      words :text, label: "Label", limit: 20
    end

    attributes do
      attribute :text, :string, public?: true
    end

    actions do
      defaults [:read, :destroy, create: :*, update: :*]
    end
  end

  defmodule Shelf do
    @moduledoc "A site's part holding another of the site's parts."
    use Billboard.Part

    editor do
      words :name, label: "Name", limit: 40
      field :label, as: :part, part: Label, optional: true, item_label: "label"
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :label, Label, public?: true
    end

    actions do
      defaults [:read, :destroy, create: :*, update: :*]
    end
  end

  defmodule Racks do
    @moduledoc "A component whose list holds a part that holds another."
    use Billboard.Component

    component do
      key :racks
      label "Racks"
      hint "Shelves, each with a label."
      category :content
      parts :shelves, Shelf
    end

    editor do
      field :shelves, as: :list, part: Shelf, item_label: "shelf"
    end
  end

  test "lists a site's part that another of its parts names, after it" do
    put_site!(components: [Racks, Billboard.Test.Notes])
    assert Parts.site_parts() == [Shelf, Label, Question]
    assert "Your label" in Billboard.EditorLive.Filler.texts()
  end

  test "a module that isn't a part says how to make it one" do
    assert_raise ArgumentError,
                 ~r/String isn't a part billboard knows. Name one of billboard's parts .* or give String `use Billboard.Part`/,
                 fn -> Parts.editor_fields(String) end
  end

  describe "the checks" do
    test "refuse a blank naming a field the part hasn't got" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.PartTest.Typo do
            use Billboard.Part

            part do
              blank %{titel: "Yours"}
            end

            attributes do
              uuid_primary_key :id
              attribute :title, :string, public?: true
            end

            actions do
              defaults [:read, :destroy, create: :*, update: :*]
            end
          end
        end

      assert [{_, [error]}] = errors

      assert error.message =~
               "`:titel` is in the blank but isn't an attribute of Billboard.PartTest.Typo. " <>
                 "Add the attribute, or take it out of the blank."
    end

    test "refuse an editor entry that isn't an attribute, as a component's are" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.PartTest.Stray do
            use Billboard.Part

            editor do
              words :subtitle, label: "Subtitle"
            end

            attributes do
              uuid_primary_key :id
              attribute :title, :string, public?: true
            end

            actions do
              defaults [:read, :destroy, create: :*, update: :*]
            end
          end
        end

      assert [{_, [error]}] = errors
      assert error.message =~ "`:subtitle` is in `editor` but isn't an attribute"
    end

    test "refuse a component's list naming a module that isn't a part" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.PartTest.Plain do
            use Billboard.Component

            component do
              key :plain_list
              label "Plain"
              hint "x"
              category :content
              parts :items, Billboard.Parts.Detail
            end

            editor do
              field :items, as: :list, part: Billboard.Parts.Detail
            end
          end
        end

      assert [{_, [error]}] = errors

      assert error.message =~
               "`:items` is a list in `editor` whose part, Billboard.Parts.Detail, isn't one " <>
                 "the editor knows. Name it by its stock name, as `part: :detail`, or give " <>
                 "Billboard.Parts.Detail `use Billboard.Part`"
    end

    defp messages(errors), do: for({_, errors} <- errors, error <- errors, do: error.message)

    test "refuse a part with no primary create, read, or update, naming the default" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.PartTest.NoCreate do
            use Billboard.Part

            attributes do
              attribute :title, :string, public?: true
            end

            actions do
              defaults [:read, :destroy, update: :*]
            end
          end

          defmodule Elixir.Billboard.PartTest.NoRead do
            use Billboard.Part

            attributes do
              attribute :title, :string, public?: true
            end

            actions do
              defaults [:destroy, create: :*, update: :*]
            end
          end

          defmodule Elixir.Billboard.PartTest.NoUpdate do
            use Billboard.Part

            attributes do
              attribute :title, :string, public?: true
            end

            actions do
              defaults [:read, :destroy, create: :*]
            end
          end
        end

      assert Enum.sort(messages(errors)) == [
               "Billboard.PartTest.NoCreate has no primary create action, and a new item is " <>
                 "built through it. Add `create: :*` to its `defaults`.",
               "Billboard.PartTest.NoRead has no primary read action, and Ash reads every " <>
                 "embedded resource through it. Add `:read` to its `defaults`.",
               "Billboard.PartTest.NoUpdate has no primary update action, and an edit to an " <>
                 "item is saved through it. Add `update: :*` to its `defaults`."
             ]
    end

    test "refuse what an item's tools can't change, and a binding a part hasn't got" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.PartTest.Overloaded do
            use Billboard.Part

            editor do
              words :title, label: "Title", bound: :hide
              field :look, as: :variants, options: [:text_only, :media_right]
              field :photo, as: :photo
              field :tags, as: :choices, from: :scope
              field :bound, as: :binding_note
              field :rows, as: :list, part: :point
            end

            attributes do
              attribute :title, :string, public?: true

              attribute :look, :atom,
                public?: true,
                constraints: [one_of: [:text_only, :media_right]]

              attribute :photo, Billboard.Parts.Photo, public?: true
              attribute :tags, {:array, :string}, public?: true
              attribute :rows, {:array, Billboard.Parts.Point}, public?: true
            end

            actions do
              defaults [:read, :destroy, create: :*, update: :*]
            end
          end
        end

      messages = messages(errors)

      assert ("`:title` is `bound: :hide` in a part's `editor`, but only a section's binding " <>
                "replaces its words, and a part has none. Take `bound:` out") in messages

      for {name, as} <- [
            look: :variants,
            photo: :photo,
            tags: :choices,
            bound: :binding_note,
            rows: :list
          ] do
        assert Enum.any?(
                 messages,
                 &(&1 =~
                     "`#{inspect(name)}` is `as: #{inspect(as)}` in a part's `editor`, but the editor changes a part's items with words")
               ),
               "expected #{name} refused"
      end

      assert length(messages) == 6
    end

    test "word a missing part's fix for a part, which holds it in an attribute" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.PartTest.Missing do
            use Billboard.Part

            editor do
              field :label, as: :part, part: Billboard.PartTest.Label
              field :names, as: :part, part: :link
            end

            attributes do
              attribute :names, :string, public?: true
            end

            actions do
              defaults [:read, :destroy, create: :*, update: :*]
            end
          end
        end

      assert Enum.sort(messages(errors)) == [
               "`:label` is in `editor` but isn't an attribute of Billboard.PartTest.Missing. " <>
                 "Add `attribute :label, MySite.Parts.Name, public?: true` to its `attributes`, " <>
                 "or take it out of `editor`",
               "`:names` is a part in `editor`, but it isn't a part. Make its attribute " <>
                 "`attribute :names, MySite.Parts.Name, public?: true`, or make it another kind " <>
                 "of entry"
             ]
    end

    test "refuse a site's part named in place of the one its attribute holds" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.PartTest.Mixed do
            use Billboard.Component

            component do
              key :mixed
              label "Mixed"
              hint "x"
              category :content
              parts :items, Billboard.PartTest.Shelf
            end

            editor do
              field :items, as: :list, part: MySite.Sections.Faq.Question
            end
          end
        end

      assert messages(errors) == [
               "`:items` is a list of MySite.Sections.Faq.Question in `editor`, but its " <>
                 "attribute holds Billboard.PartTest.Shelf. Name the part it holds, as " <>
                 "`part: Billboard.PartTest.Shelf`, or make the attribute hold " <>
                 "MySite.Sections.Faq.Question"
             ]
    end

    test "refuse a section's actions holding anything but billboard's actions" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.PartTest.Asks do
            use Billboard.Component

            component do
              key :asks
              label "Asks"
              hint "x"
              category :content
              parts :actions, MySite.Sections.Faq.Question
            end

            editor do
              field :actions, as: :list, part: MySite.Sections.Faq.Question
            end
          end
        end

      assert messages(errors) == [
               "`:actions` is where billboard's rules read a section's buttons, so it must " <>
                 "hold a list of Billboard.Parts.Action, as " <>
                 "`parts :actions, Billboard.Parts.Action` does. " <>
                 "Rename it, or hold `Billboard.Parts.Action`."
             ]
    end

    test "refuse a section's actions held under a name of the site's own, edited as points" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.PartTest.WrappedAsPoints do
            use Billboard.Component

            component do
              key :wrapped_as_points
              label "Asks"
              hint "x"
              category :content
            end

            editor do
              field :actions, as: :list, part: :point
            end

            attributes do
              attribute :actions, {:array, Billboard.Test.WrappedAction},
                public?: true,
                default: []
            end
          end
        end

      assert messages(errors) == [
               "`:actions` is a list of :point in `editor`, but " <>
                 "billboard reads a section's `:actions` as its actions " <>
                 "(`Billboard.Parts.Action`). Make it `part: :action`, or give the attribute " <>
                 "another name"
             ]
    end

    test "take a section's actions held under a name of the site's own, edited as actions" do
      refute_dsl_errors do
        defmodule Elixir.Billboard.PartTest.WrappedAsActions do
          use Billboard.Component

          component do
            key :wrapped_as_actions
            label "Asks"
            hint "x"
            category :content
          end

          editor do
            field :actions, as: :list, part: :action
          end

          attributes do
            attribute :actions, {:array, Billboard.Test.WrappedAction},
              public?: true,
              default: []
          end
        end
      end
    end

    test "refuse a section's actions edited as anything but billboard's actions" do
      errors =
        dsl_errors do
          defmodule Elixir.Billboard.PartTest.AsksAsPoints do
            use Billboard.Component

            component do
              key :asks_as_points
              label "Asks"
              hint "x"
              category :content
              parts :actions, Billboard.Parts.Action
            end

            editor do
              field :actions, as: :list, part: :point
            end
          end
        end

      assert messages(errors) == [
               "`:actions` is a list of :point in `editor`, but " <>
                 "billboard reads a section's `:actions` as its actions " <>
                 "(`Billboard.Parts.Action`). Make it `part: :action`, or give the attribute " <>
                 "another name"
             ]
    end
  end
end
