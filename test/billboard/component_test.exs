defmodule Billboard.ComponentTest do
  # Changes application env, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env
  import Spark.Test

  alias Billboard.Component.Info
  alias Billboard.Site
  alias Billboard.Test.{Banner, Note, Stamp}

  defmodule ByHand do
    @moduledoc "`Billboard.Test.Banner`, written by hand as a plain embedded resource, to compare."
    use Ash.Resource, data_layer: :embedded

    actions do
      defaults [:read, :destroy, create: :*, update: :*]
    end

    attributes do
      attribute :component, :atom do
        allow_nil? false
        default :banner
        public? true
        constraints one_of: [:banner]
      end

      attribute :heading, :string, public?: true
    end
  end

  defmodule OwnDefaults do
    @moduledoc "A component that writes its own `defaults`, which billboard keeps as written."
    use Billboard.Component

    component do
      key :own_defaults
      label "Own defaults"
      hint "Takes only its title."
      category :paper
    end

    actions do
      defaults [:read, :destroy, create: [:title], update: [:title]]
    end

    attributes do
      attribute :title, :string, public?: true
      attribute :subtitle, :string, public?: true
    end
  end

  defmodule Extended do
    @moduledoc "A component that names another extension, which billboard keeps."
    use Billboard.Component, extensions: [Billboard.Test.Extension]

    component do
      key :extended
      label "Extended"
      hint "Has another extension."
      category :paper
    end
  end

  describe "the tag" do
    test "is added as every component writes it" do
      assert attribute(Banner, :component) == attribute(ByHand, :component)
    end

    test "is set on a new component" do
      assert %Banner{component: :banner} =
               Banner |> Ash.Changeset.for_create(:create, %{}) |> Ash.create!()
    end

    test "needs a component section" do
      assert_raise Spark.Error.DslError, ~r/has no `component` section/, fn ->
        defmodule Elixir.Billboard.ComponentTest.NoSection do
          use Billboard.Component

          attributes do
            attribute :title, :string, public?: true
          end
        end
      end
    end

    test "can't be given another component's key" do
      assert {:error, %Ash.Error.Invalid{}} =
               Banner
               |> Ash.Changeset.for_create(:create, %{component: :note})
               |> Ash.create()
    end
  end

  describe "the actions" do
    test "are the four defaults, each primary" do
      for type <- [:read, :create, :update, :destroy] do
        action = Ash.Resource.Info.primary_action!(Banner, type)
        assert action.name == type
      end
    end

    test "accept every public attribute, including the tag" do
      public = Banner |> Ash.Resource.Info.public_attributes() |> Enum.map(& &1.name)

      for type <- [:create, :update] do
        accept = Ash.Resource.Info.primary_action!(Banner, type).accept
        assert Enum.sort(accept) == Enum.sort(public)
        assert :component in accept
      end
    end

    test "leave out attributes that aren't public" do
      refute :internal in Ash.Resource.Info.primary_action!(Note, :create).accept
    end

    test "are what `defaults [:read, :destroy, create: :*, update: :*]` gives" do
      assert actions(Banner) == actions(ByHand)
    end

    test "create and update a component" do
      banner =
        Banner
        |> Ash.Changeset.for_create(:create, %{heading: "x"})
        |> Ash.create!()

      assert banner.heading == "x"

      assert %Banner{heading: "y"} =
               banner |> Ash.Changeset.for_update(:update, %{heading: "y"}) |> Ash.update!()
    end

    test "keep a component's own defaults as written" do
      assert Ash.Resource.Info.primary_action!(OwnDefaults, :create).accept == [:title]
      assert Ash.Resource.Info.primary_action!(OwnDefaults, :update).accept == [:title]
      assert Ash.Resource.Info.primary_action!(OwnDefaults, :read)
      assert Ash.Resource.Info.primary_action!(OwnDefaults, :destroy)
    end

    test "leave a component's own action alone" do
      create = Ash.Resource.Info.primary_action!(Stamp, :create)
      assert create.accept == [:word]

      assert Ash.Resource.Info.primary_action!(Stamp, :update).accept |> Enum.sort() ==
               [:component, :size, :word]

      assert Stamp |> Ash.Resource.Info.actions() |> Enum.count(&(&1.type == :create)) == 1
    end
  end

  describe "Info" do
    test "returns every option" do
      assert Info.component_key!(Banner) == :banner
      assert Info.component_label!(Banner) == "Banner"
      assert Info.component_hint!(Banner) == "One idea, set apart."
      assert Info.component_category!(Banner) == :band
      assert Info.component_kinds!(Banner) == [:free]
      assert Info.component_max!(Banner) == 2
      assert Info.component_column?(Banner) == false
      assert Info.component_mirror?(Banner) == true
      assert Info.component_surface_kind!(Banner) == :stand_out
      assert Info.component_surface_from!(Banner) == :library
      assert Info.component_placeholder!(Banner) == %{heading: "Your banner"}
    end

    test "gives defaults for the options left out" do
      assert Info.component_kinds!(Note) == :all
      assert Info.component_max(Note) == {:ok, nil}
      assert Info.component_column?(Note) == false
      assert Info.component_mirror?(Note) == false
      assert Info.component_surface_kind!(Note) == :page
      assert Info.component_surface_from(Note) == {:ok, nil}
      assert Info.component_placeholder!(Note) == %{}
    end

    test "component?/1 knows a component" do
      assert Info.component?(Banner)
      refute Info.component?(Billboard.Test.Site)
      refute Info.component?(Billboard.Test.Plain)
      refute Info.component?(:not_a_module)
    end
  end

  describe "the verifiers" do
    test "refuse a tag of the component's own with another one_of" do
      {:error, error} =
        dsl_error(fn ->
          defmodule Elixir.Billboard.ComponentTest.BadTag do
            use Billboard.Component

            component do
              key :faq
              label "FAQ"
              hint "Questions."
              category :paper
            end

            attributes do
              attribute :component, :atom, public?: true, constraints: [one_of: [:faqs]]
            end
          end
        end)

      assert error.message ==
               "Billboard.ComponentTest.BadTag's `component` attribute must be " <>
                 "`allow_nil?: false, default: :faq, constraints: [one_of: [:faq]]`. " <>
                 "Take it out; billboard adds it."
    end

    test "refuse a tag of the component's own, naming every setting that differs" do
      {:error, error} =
        dsl_error(fn ->
          defmodule Elixir.Billboard.ComponentTest.StringTag do
            use Billboard.Component

            component do
              key :faq
              label "FAQ"
              hint "Questions."
              category :paper
            end

            attributes do
              attribute :component, :string do
                allow_nil? false
                default :faq
                constraints max_length: 10
              end
            end
          end
        end)

      # Ash casts the default to the attribute's type, so it differs too.
      assert error.message ==
               "Billboard.ComponentTest.StringTag's `component` attribute must be " <>
                 "`:atom, default: :faq, public?: true, constraints: [one_of: [:faq]]`. " <>
                 "Take it out; billboard adds it."
    end

    for {type, defaults, fix, reason} <- [
          {:read, [:destroy, create: :*, update: :*], "`:read`",
           "Ash reads every embedded resource through it"},
          {:create, [:read, :destroy, update: :*], "`create: :*`",
           "Ash builds a new section's component through it"},
          {:update, [:read, :destroy, create: :*], "`update: :*`",
           "Ash saves an edit to a section's component through it"},
          {:destroy, [:read, create: :*, update: :*], "`:destroy`",
           "Ash destroys a section's component when it's replaced"}
        ] do
      test "refuse a component without a primary #{type} action" do
        module = Module.concat(Billboard.ComponentTest, "No#{unquote(type)}")

        {:error, error} =
          dsl_error(fn ->
            defmodule module do
              use Billboard.Component

              component do
                key :faq
                label "FAQ"
                hint "Questions."
                category :paper
              end

              actions do
                defaults unquote(defaults)
              end
            end
          end)

        assert error.message ==
                 "#{inspect(module)} has no primary #{unquote(type)} action, and " <>
                   "#{unquote(reason)}. Add #{unquote(fix)} to its `defaults`, or take " <>
                   "`defaults` out; billboard adds them."
      end
    end

    test "refuse a public placeholder key that a hand-written create leaves out" do
      {:error, error} =
        dsl_error(fn ->
          defmodule Elixir.Billboard.ComponentTest.NarrowCreate do
            use Billboard.Component

            component do
              key :narrow
              label "Narrow"
              hint "Takes only its word."
              category :paper
              placeholder %{size: 3}
            end

            actions do
              create :create do
                primary? true
                accept [:word]
              end
            end

            attributes do
              attribute :word, :string, public?: true
              attribute :size, :integer, public?: true
            end
          end
        end)

      assert error.message ==
               "`:size` is in the placeholder, but " <>
                 "Billboard.ComponentTest.NarrowCreate's create doesn't accept it, and a new " <>
                 "section is built through create. Add it to the create's `accept`, or take " <>
                 "it out of the placeholder."
    end

    test "refuse a private placeholder key" do
      {:error, error} =
        dsl_error(fn ->
          defmodule Elixir.Billboard.ComponentTest.PrivatePlaceholder do
            use Billboard.Component

            component do
              key :faq
              label "FAQ"
              hint "Questions."
              category :paper
              placeholder %{secret: "Questions"}
            end

            attributes do
              attribute :secret, :string
            end
          end
        end)

      assert error.message ==
               "`:secret` is in the placeholder, but " <>
                 "Billboard.ComponentTest.PrivatePlaceholder's create doesn't accept it, " <>
                 "and a new section is built through create. Make the attribute " <>
                 "`public?: true`, or take it out of the placeholder."
    end

    test "refuse a placeholder key that isn't an attribute" do
      {:error, error} =
        dsl_error(fn ->
          defmodule Elixir.Billboard.ComponentTest.BadPlaceholder do
            use Billboard.Component

            component do
              key :faq
              label "FAQ"
              hint "Questions."
              category :paper
              placeholder %{titel: "Questions"}
            end

            attributes do
              attribute :title, :string, public?: true
            end
          end
        end)

      assert error.message ==
               "`:titel` is in the placeholder but isn't an attribute of " <>
                 "Billboard.ComponentTest.BadPlaceholder. Add the attribute, " <>
                 "or take it out of the placeholder."
    end

    test "refuse a section drawn as a card" do
      {:error, error} =
        dsl_error(fn ->
          defmodule Elixir.Billboard.ComponentTest.CardKind do
            use Billboard.Component

            component do
              key :card_kind
              label "Card kind"
              hint "A section that thinks it's a card."
              category :paper
              surface_kind :card
            end
          end
        end)

      assert error.message ==
               "Billboard.ComponentTest.CardKind's `surface_kind` is `:card`, but `:card` is " <>
                 "the kind of a card inside a section, not of a section, and a section needs " <>
                 "a ground of its own. Use `:page`, `:stand_out`, or another kind the site " <>
                 "offers its sections."
    end

    test "pass a good component" do
      refute_dsl_errors do
        defmodule Elixir.Billboard.ComponentTest.Good do
          use Billboard.Component

          component do
            key :good
            label "Good"
            hint "Nothing wrong."
            category :paper
            placeholder %{title: "Hello"}
          end

          attributes do
            attribute :title, :string, public?: true
          end
        end
      end
    end
  end

  describe "use Billboard.Component" do
    test "keeps the extensions it's given" do
      extensions = Spark.extensions(Extended)

      assert Billboard.Component.Dsl in extensions
      assert Billboard.Test.Extension in extensions
      assert Info.component_key!(Extended) == :extended
    end

    test "refuses a data layer, naming the fix" do
      assert_raise ArgumentError,
                   ~r/sets `data_layer: :embedded` itself. Take `data_layer:` out/,
                   fn ->
                     Code.eval_quoted(
                       quote do
                         defmodule Billboard.ComponentTest.WithDataLayer do
                           use Billboard.Component, data_layer: Ash.DataLayer.Ets
                         end
                       end
                     )
                   end
    end
  end

  describe "build/2 and build!/2" do
    test "returns a component with what it's given, and its defaults applied" do
      assert %Billboard.Test.Columns{variant: :even} = Billboard.Component.build!(:columns, %{})

      assert %Billboard.Components.Hero{heading: "Hi"} =
               Billboard.Component.build!(:hero, %{heading: "Hi"})
    end

    test "raises on content that breaks the component's rules" do
      assert_raise Ash.Error.Invalid, fn -> Billboard.Component.build!(:hero, %{}) end
    end

    test "build/2 returns the error instead" do
      assert {:error, %Ash.Error.Invalid{}} = Billboard.Component.build(:hero, %{})
    end

    test "raises for a type the site doesn't list" do
      assert_raise KeyError, fn -> Billboard.Component.build!(:nope, %{}) end
    end
  end

  describe "Site.component!/1" do
    test "finds a component by its key" do
      put_site!(components: [Note, Banner])
      assert Site.components() == [Note, Banner]
      assert Site.component!(:banner) == Banner
    end

    test "raises for a key the site doesn't list" do
      put_site!(components: [Banner])

      assert_raise ArgumentError, ~r/the site has no component :nope/, fn ->
        Site.component!(:nope)
      end
    end

    test "raises, naming the module, when the site lists one that isn't a component" do
      put_site!(components: [Banner, Billboard.Test.Plain])

      assert_raise ArgumentError,
                   ~r/lists Billboard.Test.Plain, which isn't a billboard component. Add `use Billboard.Component` to it, or take it out of components\/0/,
                   fn -> Site.component!(:nope) end
    end
  end

  # The one DSL error a module's definition produces, or the test fails.
  defp dsl_error(define) do
    assert [{_module, [error]}] = dsl_errors(do: define.())
    {:error, error}
  end

  defp attribute(resource, name) do
    resource |> Ash.Resource.Info.attribute(name) |> Map.delete(:__spark_metadata__)
  end

  defp actions(resource) do
    resource
    |> Ash.Resource.Info.actions()
    |> Enum.map(&Map.drop(&1, [:__spark_metadata__]))
    |> Enum.sort_by(& &1.name)
  end
end
