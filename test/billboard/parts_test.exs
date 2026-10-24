defmodule Billboard.PartsTest do
  # Creates read the site's options from app env, but this module never
  # changes it, and ExUnit runs the modules that do (async: false) only
  # once the async ones have finished.
  use ExUnit.Case, async: true

  import Spark.Test

  alias Billboard.Component.Info
  alias Billboard.Test.{Cards, PartsByHand, Item, Shelf, Title}

  describe "the attributes" do
    test "are what the parts would be written as by hand" do
      for {component, name} <- [
            {Cards, :head},
            {Cards, :items},
            {Shelf, :label},
            {Shelf, :sign},
            {Shelf, :things}
          ] do
        assert attribute(component, name) == attribute(PartsByHand, name), "#{name} differs"
      end
    end

    test "a part is its type, public, and may be nil" do
      head = Ash.Resource.Info.attribute(Cards, :head)

      assert head.type == Title
      assert head.public?
      assert head.allow_nil?
    end

    test "a list of parts is an array, public, never nil, empty by default, and bounded" do
      items = Ash.Resource.Info.attribute(Cards, :items)

      assert items.type == {:array, Item}
      assert items.public?
      refute items.allow_nil?
      assert items.default == []
      assert items.constraints[:min_length] == 1
      assert items.constraints[:max_length] == 4
    end

    test "take allow_nil? and description" do
      label = Ash.Resource.Info.attribute(Shelf, :label)
      refute label.allow_nil?
      assert label.description == "The shelf's label."

      things = Ash.Resource.Info.attribute(Shelf, :things)
      assert things.allow_nil?
      assert things.description == "What's on it."
    end

    test "a part takes a default, which a new component starts with" do
      assert Ash.Resource.Info.attribute(Shelf, :sign).default == %Title{title: "Open"}
      assert Ash.Resource.Info.attribute(Shelf, :label).default == nil

      shelf =
        Shelf
        |> Ash.Changeset.for_create(:create, %{label: %{title: "Books"}})
        |> Ash.create!()

      assert %Title{title: "Open"} = shelf.sign
    end

    test "leave min and max out when they aren't given" do
      constraints = Ash.Resource.Info.attribute(Shelf, :things).constraints

      refute Keyword.has_key?(constraints, :min_length)
      refute Keyword.has_key?(constraints, :max_length)
    end
  end

  describe "Info" do
    test "lists the parts in the order written" do
      assert [%{name: :head, type: Title}, %{name: :items, type: Item, min: 1, max: 4}] =
               Info.parts(Cards)
    end
  end

  describe "a list of parts" do
    test "is accepted by create and update" do
      for type <- [:create, :update] do
        accept = Ash.Resource.Info.primary_action!(Cards, type).accept
        assert :head in accept
        assert :items in accept
      end
    end

    test "holds items given through create" do
      cards =
        Cards
        |> Ash.Changeset.for_create(:create, %{
          head: %{title: "Hello"},
          items: [%{title: "One"}, %{title: "Two"}]
        })
        |> Ash.create!()

      assert %Title{title: "Hello"} = cards.head
      assert [%Item{title: "One", id: id}, %Item{title: "Two"}] = cards.items
      assert is_binary(id)
    end

    test "refuses more than its max" do
      items = for n <- 1..5, do: %{title: "#{n}"}

      assert {:error, %Ash.Error.Invalid{}} =
               Cards
               |> Ash.Changeset.for_create(:create, %{items: items})
               |> Ash.create()
    end
  end

  describe "the verifier" do
    test "refuses a part without a destroy action" do
      assert error_message(fn ->
               defmodule Elixir.Billboard.PartsTest.NoDestroyPart do
                 use Billboard.Component

                 component do
                   key :x
                   label "X"
                   hint "x"
                   category :paper
                   part :thing, Billboard.Test.NoDestroy
                 end
               end
             end) ==
               "Billboard.Test.NoDestroy has no destroy action, and Ash destroys a part " <>
                 "when it's dropped from a list. Add " <>
                 "`defaults [:read, :destroy, create: :*, update: :*]` to its actions."
    end

    test "refuses an `:action` that isn't billboard's action, which the rules read" do
      assert error_message(fn ->
               defmodule Elixir.Billboard.PartsTest.OtherAction do
                 use Billboard.Component

                 component do
                   key :x
                   label "X"
                   hint "x"
                   category :paper
                   part :action, Billboard.Test.Title
                 end
               end
             end) ==
               "`:action` is where billboard's rules read a section's button, so it must " <>
                 "hold Billboard.Parts.Action, as `part :action, Billboard.Parts.Action` does. " <>
                 "Rename it, or hold `Billboard.Parts.Action`."
    end

    test "refuses `:actions` that aren't billboard's actions, even as a plain attribute" do
      assert error_message(fn ->
               defmodule Elixir.Billboard.PartsTest.OtherActions do
                 use Billboard.Component

                 component do
                   key :x
                   label "X"
                   hint "x"
                   category :paper
                 end

                 attributes do
                   attribute :actions, {:array, :string}, public?: true
                 end
               end
             end) ==
               "`:actions` is where billboard's rules read a section's buttons, so it must " <>
                 "hold a list of Billboard.Parts.Action, as " <>
                 "`parts :actions, Billboard.Parts.Action` does. " <>
                 "Rename it, or hold `Billboard.Parts.Action`."
    end

    test "refuses a part that isn't an Ash resource" do
      assert error_message(fn ->
               defmodule Elixir.Billboard.PartsTest.NotResourcePart do
                 use Billboard.Component

                 component do
                   key :x
                   label "X"
                   hint "x"
                   category :paper
                   part :thing, :string
                 end
               end
             end) =~ "Ash.Type.String isn't an Ash resource"
    end

    test "refuses a list of parts without an id" do
      assert error_message(fn ->
               defmodule Elixir.Billboard.PartsTest.NoIdParts do
                 use Billboard.Component

                 component do
                   key :x
                   label "X"
                   hint "x"
                   category :paper
                   parts :things, Billboard.Test.NoId
                 end
               end
             end) ==
               "Billboard.Test.NoId sits in a list, so it needs `uuid_primary_key :id`: " <>
                 "without one, a list change rebuilds every item from its params alone."
    end

    test "lets a part used singly go without an id" do
      refute_dsl_errors do
        defmodule Elixir.Billboard.PartsTest.SingleNoId do
          use Billboard.Component

          component do
            key :x
            label "X"
            hint "x"
            category :paper
            part :thing, Billboard.Test.NoId
          end
        end
      end
    end
  end

  describe "a part that can't be added" do
    test "is named like an attribute" do
      assert_raise Spark.Error.DslError,
                   ~r/`:head` is both a part and an attribute of Billboard.PartsTest.Clash. Rename the part, or take the attribute out./,
                   fn ->
                     defmodule Elixir.Billboard.PartsTest.Clash do
                       use Billboard.Component

                       component do
                         key :x
                         label "X"
                         hint "x"
                         category :paper
                         part :head, Billboard.Test.Title
                       end

                       attributes do
                         attribute :head, :string, public?: true
                       end
                     end
                   end
    end

    test "is named like the tag" do
      assert_raise Spark.Error.DslError,
                   ~r/`:component` is the tag billboard adds to every component, so a part can't take its name. Rename the part./,
                   fn ->
                     defmodule Elixir.Billboard.PartsTest.TagClash do
                       use Billboard.Component

                       component do
                         key :x
                         label "X"
                         hint "x"
                         category :paper
                         part :component, Billboard.Test.Title
                       end
                     end
                   end
    end

    test "is named like another part" do
      assert_raise Spark.Error.DslError,
                   ~r/has two parts named `:things`. Rename one of them./,
                   fn ->
                     defmodule Elixir.Billboard.PartsTest.Twice do
                       use Billboard.Component

                       component do
                         key :x
                         label "X"
                         hint "x"
                         category :paper
                         part :things, Billboard.Test.Title
                         parts :things, Billboard.Test.Item
                       end
                     end
                   end
    end

    test "has a min above its max" do
      assert_raise Spark.Error.DslError,
                   ~r/`parts :items` has `min: 3` above `max: 2`, so no list could hold it. Make `min` at most `max`./,
                   fn ->
                     defmodule Elixir.Billboard.PartsTest.MinAboveMax do
                       use Billboard.Component

                       component do
                         key :x
                         label "X"
                         hint "x"
                         category :paper
                         parts :items, Billboard.Test.Item, min: 3, max: 2
                       end
                     end
                   end
    end
  end

  # The message of the one DSL error a module's definition produces.
  defp error_message(define) do
    assert [{_module, [error]}] = dsl_errors(do: define.())
    error.message
  end

  defp attribute(resource, name) do
    resource |> Ash.Resource.Info.attribute(name) |> Map.delete(:__spark_metadata__)
  end
end
