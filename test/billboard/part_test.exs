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
  end
end
