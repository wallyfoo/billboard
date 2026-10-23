defmodule Billboard.SiteOptionsTest do
  # Changes application env, which every test reads, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Ash.Error.Changes.InvalidAttribute
  alias Billboard.SiteOptions
  alias Billboard.Test.{Banner, Cards, Note, Section, Shelf}

  defmodule Preset do
    @moduledoc "A component whose own change sets a field the site narrows."
    use Billboard.Component

    component do
      key :preset
      label "Preset"
      hint "Starts as cards, whatever the site's default."
      category :paper
    end

    changes do
      change set_attribute(:look, :cards), on: [:create]
    end

    attributes do
      attribute :look, :atom,
        default: :rows,
        public?: true,
        constraints: [one_of: [:rows, :cards]]
    end
  end

  defmodule Styled do
    @moduledoc "A component with a map setting and an optional one, whose values aren't simple."
    use Billboard.Component

    component do
      key :styled
      label "Styled"
      hint "Takes a style."
      category :paper
    end

    attributes do
      attribute :style, :map, public?: true
      attribute :tone, :atom, public?: true, constraints: [one_of: [:warm, :cool]]
    end
  end

  @looks [{"Rows", :rows}, {"Cards", :cards}]

  setup do
    put_site!(components: [Banner, Cards, Note, Preset, Shelf, Styled])
  end

  describe "an offer" do
    test "is everything for a field the site doesn't name" do
      assert SiteOptions.offered(:cards, :look) == :all
      assert SiteOptions.offers?(:cards, :look, :cards)
      assert SiteOptions.options(:cards, :look, @looks) == @looks
    end

    test "is the list or range the site names" do
      put_site!(options: [cards: [look: [:cards], items: 1..2]])

      assert SiteOptions.offered(:cards, :look) == [:cards]
      assert SiteOptions.offered(:cards, :items) == 1..2
    end

    test "keeps a select to the values offered, in the component's order" do
      put_site!(options: [cards: [look: [:cards, :rows]]])
      assert SiteOptions.options(:cards, :look, @looks) == @looks

      put_site!(options: [cards: [look: [:cards]]])
      assert SiteOptions.options(:cards, :look, @looks) == [{"Cards", :cards}]
      refute SiteOptions.offers?(:cards, :look, :rows)
    end

    test "of a range measures only a list, and says so" do
      put_site!(options: [cards: [items: 1..2]])

      assert_raise ArgumentError, ~r/measures a list for :cards's :items, and 3 isn't one/, fn ->
        SiteOptions.offers?(:cards, :items, 3)
      end

      assert_raise ArgumentError, ~r/and 2 isn't one/, fn ->
        SiteOptions.options(:cards, :items, [{"Two", 2}])
      end
    end

    test "of a range offers a list whose length is in it" do
      put_site!(options: [cards: [items: 1..2]])

      assert SiteOptions.offers?(:cards, :items, [:a])
      assert SiteOptions.offers?(:cards, :items, [:a, :b])
      refute SiteOptions.offers?(:cards, :items, [:a, :b, :c])
      refute SiteOptions.offers?(:cards, :items, nil)
    end

    test "is listed for every field the site names, in its order" do
      put_site!(options: [cards: [look: [:cards, :rows], columns: [2], items: 1..3]])

      assert SiteOptions.narrowed(:cards) == [
               look: [:cards, :rows],
               columns: [2],
               items: 1..3
             ]
    end

    test "lists nothing for a type the site names no options for, without looking it up" do
      assert SiteOptions.narrowed(:cards) == []
      assert SiteOptions.narrowed(:not_a_component) == []
    end
  end

  describe "an offer that can't be kept" do
    test "names a field the component has" do
      put_site!(options: [cards: [layout: [:grid]]])

      assert_raise ArgumentError,
                   ~r/:cards's :layout, which isn't one of its fields. Take it out .* or name one of \[:columns, :look, :head, :items\]/,
                   fn -> SiteOptions.offered(:cards, :layout) end
    end

    test "offers only the field's own options" do
      put_site!(options: [cards: [look: [:rows, :tiles]]])

      assert_raise ArgumentError,
                   ~r/:cards's :look :tiles, which it can't hold: atom must be one of rows, cards, got: tiles. Take it out of the site's options\/0/,
                   fn -> SiteOptions.options(:cards, :look, @looks) end
    end

    test "offers an integer within its bounds" do
      for {outside, reason} <- [
            {1, "must be greater than or equal to 2"},
            {5, "must be less than or equal to 4"}
          ] do
        put_site!(options: [cards: [columns: [3, outside]]])

        assert_raise ArgumentError,
                     ~r/:cards's :columns #{outside}, which it can't hold: #{reason}/,
                     fn -> SiteOptions.offered(:cards, :columns) end
      end
    end

    test "offers a value the field can hold" do
      put_site!(options: [cards: [columns: [3, "three"]]])

      assert_raise ArgumentError, ~r/:columns "three", which it can't hold: is invalid/, fn ->
        SiteOptions.offered(:cards, :columns)
      end
    end

    test "offers each value as the field stores it" do
      put_site!(options: [cards: [columns: [3, "2"]], styled: [tone: ["warm"]]])

      assert_raise ArgumentError, ~r/:columns "2", which it stores as 2. Offer 2 instead/, fn ->
        SiteOptions.offered(:cards, :columns)
      end

      assert_raise ArgumentError, ~r/:tone "warm", which it stores as :warm/, fn ->
        SiteOptions.offered(:styled, :tone)
      end
    end

    test "offers a list of values only for a field that isn't a list" do
      put_site!(options: [cards: [items: [1, 2]]])

      assert_raise ArgumentError,
                   ~r/:cards's :items a list of values, but :items is a list, so offer a range of its lengths, such as 1..3/,
                   fn -> SiteOptions.offered(:cards, :items) end
    end

    test "offers a range only for a list" do
      put_site!(options: [cards: [columns: 2..3]])

      assert_raise ArgumentError,
                   ~r/a range offers a list's lengths, and :columns isn't a list/,
                   fn ->
                     SiteOptions.offered(:cards, :columns)
                   end
    end

    test "offers a range within the list's own lengths" do
      for outside <- [0..2, 1..5] do
        put_site!(options: [cards: [items: outside]])

        assert_raise ArgumentError, ~r/outside the lengths it allows, 1 to 4/, fn ->
          SiteOptions.offered(:cards, :items)
        end
      end
    end

    test "offers a range that counts up by one" do
      for range <- [1..3//2, 3..1//-1] do
        put_site!(options: [cards: [items: range]])

        assert_raise ArgumentError, ~r/doesn't count up by one/, fn ->
          SiteOptions.offered(:cards, :items)
        end
      end
    end

    test "offers at least one value" do
      put_site!(options: [cards: [look: []]])

      assert_raise ArgumentError, ~r/offers nothing for :cards's :look. Offer at least one/, fn ->
        SiteOptions.offered(:cards, :look)
      end
    end

    test "is a list or a range" do
      put_site!(options: [cards: [look: :cards]])

      assert_raise ArgumentError, ~r/isn't a list or a range/, fn ->
        SiteOptions.offered(:cards, :look)
      end
    end

    test "is checked by narrowed/1 too" do
      put_site!(options: [cards: [look: [:tiles]]])

      assert_raise ArgumentError, ~r/which it can't hold/, fn ->
        SiteOptions.narrowed(:cards)
      end
    end
  end

  describe "default/2" do
    test "is a list's first" do
      put_site!(options: [cards: [look: [:cards, :rows]]])
      assert SiteOptions.default(:cards, :look) == {:ok, :cards}
    end

    test "is none for a range, or a field the site doesn't name" do
      put_site!(options: [cards: [items: 1..2]])

      assert SiteOptions.default(:cards, :items) == :error
      assert SiteOptions.default(:cards, :look) == :error
    end
  end

  describe "resolve/3" do
    test "keeps a value the site offers" do
      put_site!(options: [cards: [look: [:cards, :rows]]])
      assert SiteOptions.resolve(:cards, :look, :rows) == :rows
    end

    test "gives the site's default for one it doesn't" do
      put_site!(options: [cards: [look: [:cards]]])

      assert SiteOptions.resolve(:cards, :look, :rows) == :cards
      assert SiteOptions.resolve(:cards, :look, nil) == :cards
    end

    test "returns the value for a range, or a field the site doesn't name" do
      put_site!(options: [cards: [items: 1..2]])

      assert SiteOptions.resolve(:cards, :items, [:a, :b, :c]) == [:a, :b, :c]
      assert SiteOptions.resolve(:cards, :look, :rows) == :rows
    end
  end

  describe "max_length/2" do
    test "is the range's last" do
      put_site!(options: [cards: [items: 1..2]])
      assert SiteOptions.max_length(:cards, :items) == 2
    end

    test "is the list's own max_length when the site doesn't narrow it" do
      assert SiteOptions.max_length(:cards, :items) == 4
    end

    test "is nil for a list with no max_length" do
      assert SiteOptions.max_length(:shelf, :things) == nil
    end

    test "raises for a field that isn't a list, naming the fix" do
      assert_raise ArgumentError,
                   ~r/:cards's :columns isn't a list, so it has no length. Ask max_length\/2 about a list field/,
                   fn -> SiteOptions.max_length(:cards, :columns) end

      put_site!(options: [cards: [columns: [2, 3]]])

      assert_raise ArgumentError, ~r/isn't a list/, fn ->
        SiteOptions.max_length(:cards, :columns)
      end
    end
  end

  describe "a new component" do
    test "takes the site's first for a field it isn't given" do
      put_site!(options: [cards: [look: [:cards, :rows], columns: [2, 3]]])

      assert %Cards{look: :cards, columns: 2} = create!(%{})
    end

    test "keeps a value it's given, even the component's own default" do
      put_site!(options: [cards: [look: [:cards, :rows], columns: [2, 3]]])

      assert %Cards{look: :rows, columns: 3} = create!(%{look: :rows, columns: 3})
      assert %Cards{look: :rows} = create!(%{"look" => "rows"})
    end

    test "keeps the component's own default for a field the site doesn't name" do
      put_site!(options: [cards: [look: [:cards, :rows]]])
      assert %Cards{columns: 3} = create!(%{})
    end

    test "keeps what the component's own change sets" do
      put_site!(options: [preset: [look: [:rows, :cards]]])

      assert %Preset{look: :cards} =
               Preset |> Ash.Changeset.for_create(:create, %{}) |> Ash.create!()
    end

    test "is refused a value the site doesn't offer" do
      put_site!(options: [cards: [look: [:rows]]])

      assert errors(create(%{look: :cards})) == [look: "this site doesn't offer “cards” here"]
    end

    test "is refused a list longer than the range" do
      put_site!(options: [cards: [items: 1..2]])

      assert errors(create(%{items: items(3)})) == [items: "this site shows at most 2 here"]
    end

    test "saves a list nobody chose, even one shorter than the range" do
      put_site!(options: [shelf: [things: 1..2], cards: [items: 2..3]])

      assert %Shelf{things: []} =
               Shelf
               |> Ash.Changeset.for_create(:create, %{label: %{title: "A"}})
               |> Ash.create!()

      assert %Cards{items: [_]} = create!(%{items: items(1)})
    end

    test "is refused a list past the range's last, given or not" do
      put_site!(options: [shelf: [things: 1..2]])

      assert {:error, %Ash.Error.Invalid{errors: [%InvalidAttribute{field: :things} = error]}} =
               Shelf
               |> Ash.Changeset.for_create(:create, %{label: %{title: "A"}, things: items(3)})
               |> Ash.create()

      assert error.message == "this site shows at most 2 here"
    end

    test "puts the refused value on the error" do
      put_site!(options: [cards: [look: [:rows]]])

      assert {:error, %Ash.Error.Invalid{errors: [%InvalidAttribute{value: :cards}]}} =
               create(%{look: :cards})
    end

    test "says a value that isn't text or a number plainly" do
      put_site!(options: [styled: [style: [%{"weight" => "bold"}]]])

      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               Styled
               |> Ash.Changeset.for_create(:create, %{style: %{"weight" => "light"}})
               |> Ash.create()

      assert error.message == ~s(this site doesn't offer “%{"weight" => "light"}” here)
    end

    test "may be nil for a field that allows it" do
      put_site!(options: [styled: [tone: [:warm]]])

      assert {:ok, %Styled{tone: nil}} =
               Styled |> Ash.Changeset.for_create(:create, %{tone: nil}) |> Ash.create()
    end
  end

  describe "an updated component" do
    test "is refused nil only by the field itself, when it doesn't allow it" do
      cards = create!(%{})
      put_site!(options: [cards: [look: [:rows]]])

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.Required{field: :look}]}} =
               update(cards, %{look: nil})
    end

    test "never takes a default" do
      cards = create!(%{})
      put_site!(options: [cards: [look: [:cards, :rows], columns: [2, 3]]])

      assert %Cards{look: :rows, columns: 3} = update!(cards, %{head: %{title: "New"}})
    end

    test "is refused a value the site doesn't offer" do
      cards = create!(%{})
      put_site!(options: [cards: [look: [:rows]]])

      assert errors(update(cards, %{look: :cards})) == [
               look: "this site doesn't offer “cards” here"
             ]
    end

    test "keeps a value the site has stopped offering while it saves another field" do
      cards = create!(%{look: :cards})
      put_site!(options: [cards: [look: [:rows]]])

      assert %Cards{look: :cards, columns: 2} = update!(cards, %{columns: 2})
      assert %Cards{look: :cards, columns: 2} = update!(cards, %{look: :cards, columns: 2})
    end

    test "is refused a list that grows past the range" do
      cards = create!(%{items: items(2)})
      put_site!(options: [cards: [items: 1..2]])

      assert errors(update(cards, %{items: items(3)})) == [
               items: "this site shows at most 2 here"
             ]
    end

    test "is refused a list that shrinks below the range" do
      cards = create!(%{items: items(2)})
      put_site!(options: [cards: [items: 2..3]])

      assert errors(update(cards, %{items: items(1)})) == [
               items: "this site needs at least 2 here"
             ]
    end

    test "saves an edit to an item in a list already longer than the range" do
      cards = create!(%{items: items(4)})
      put_site!(options: [cards: [items: 1..2]])

      edited = Enum.map(cards.items, &%{id: &1.id, title: &1.title <> "!"})

      assert %Cards{items: [%{title: "1!"} | _] = saved} = update!(cards, %{items: edited})
      assert length(saved) == 4
    end

    test "may shrink towards the range, but not grow further from it" do
      four = create!(%{items: items(4)})
      three = create!(%{items: items(3)})
      put_site!(options: [cards: [items: 1..2]])

      assert %Cards{items: [_, _, _]} = update!(four, %{items: Enum.take(ids(four), 3)})

      assert errors(update(three, %{items: ids(three) ++ [%{title: "4"}]})) ==
               [items: "this site shows at most 2 here"]
    end
  end

  describe "inside a section's content union" do
    test "a refusal is an error on the component's field, at the content's path" do
      put_site!(options: [cards: [look: [:rows]]])

      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               Section
               |> Ash.Changeset.for_create(:create, %{
                 content: %{"component" => "cards", "look" => "cards", "items" => items(1)}
               })
               |> Ash.create()

      assert %InvalidAttribute{field: :look, path: [:content]} = error
      assert error.message == "this site doesn't offer “cards” here"
    end

    test "an update to the stored component is refused the same way" do
      section =
        Section
        |> Ash.Changeset.for_create(:create, %{
          content: %{"component" => "cards", "items" => items(1)}
        })
        |> Ash.create!()

      put_site!(options: [cards: [look: [:rows]]])

      assert {:error,
              %Ash.Error.Invalid{errors: [%InvalidAttribute{field: :look, path: [:content]}]}} =
               section
               |> Ash.Changeset.for_update(:update, %{
                 content: %{"component" => "cards", "look" => "cards"}
               })
               |> Ash.update()
    end

    test "a new component takes the site's defaults" do
      put_site!(options: [cards: [look: [:cards, :rows], columns: [2, 3]]])

      assert %Section{content: %Ash.Union{type: :cards, value: %Cards{look: :cards, columns: 2}}} =
               Section
               |> Ash.Changeset.for_create(:create, %{
                 content: %{"component" => "cards", "items" => items(1)}
               })
               |> Ash.create!()
    end
  end

  describe "the change" do
    test "is added to every component, after its own, for create and update" do
      for component <- [Banner, Cards, Note] do
        assert [%{change: {Billboard.Changes.SiteOptions, []}, on: [:create, :update]}] =
                 Ash.Resource.Info.changes(component)
      end

      assert [
               %{change: {Ash.Resource.Change.SetAttribute, _}},
               %{change: {Billboard.Changes.SiteOptions, []}}
             ] =
               Ash.Resource.Info.changes(Preset)
    end
  end

  defp items(n), do: for(i <- 1..n, do: %{title: "#{i}"})
  defp ids(cards), do: Enum.map(cards.items, &%{id: &1.id})

  # Cards needs at least one item, so a create that doesn't say gets one.
  defp create(params) do
    params = Map.put_new(params, :items, items(1))
    Cards |> Ash.Changeset.for_create(:create, params) |> Ash.create()
  end

  defp create!(params) do
    {:ok, cards} = create(params)
    cards
  end

  defp update(cards, params),
    do: cards |> Ash.Changeset.for_update(:update, params) |> Ash.update()

  defp update!(cards, params) do
    {:ok, cards} = update(cards, params)
    cards
  end

  defp errors({:error, %Ash.Error.Invalid{errors: errors}}),
    do:
      Enum.map(errors, fn %InvalidAttribute{field: field, message: message} ->
        {field, message}
      end)
end
