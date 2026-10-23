defmodule Billboard.ComponentTest do
  # Changes application env, so not async.
  use ExUnit.Case, async: false

  import Billboard.Test.Env
  import Spark.Test

  alias Billboard.Component.Info
  alias Billboard.Site
  alias Billboard.Test.{Banner, Note, Stamp}

  describe "the tag" do
    test "is added as every component writes it" do
      tag = Ash.Resource.Info.attribute(Banner, :component)

      assert tag.type == Ash.Type.Atom
      assert tag.allow_nil? == false
      assert tag.default == :banner
      assert tag.public? == true
      assert tag.constraints[:one_of] == [:banner]
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
      defmodule Elixir.Billboard.ComponentTest.ByHand do
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

      assert actions(Banner) == actions(Billboard.ComponentTest.ByHand)
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
                 "`one_of: [:faq]`. Take it out; billboard adds it."
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
  end

  # The one DSL error a module's definition produces, or the test fails.
  defp dsl_error(define) do
    assert [{_module, [error]}] = dsl_errors(do: define.())
    {:error, error}
  end

  defp actions(resource) do
    resource
    |> Ash.Resource.Info.actions()
    |> Enum.map(&Map.drop(&1, [:__spark_metadata__]))
    |> Enum.sort_by(& &1.name)
  end
end
