defmodule Billboard.ContextTest do
  @moduledoc "What a site's pages are about: the bindings a hero may take, and pickers' choices."
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Context

  test "a site with no context module has no bindings, and no choices" do
    put_site!(context: nil)
    assert Context.bindings() == []
    refute Context.replaces_words?(:product)
    assert Context.choice_sets() == []
    assert Context.choices_for([:scope]) == %{}

    assert_raise ArgumentError, ~r/offers no choices called :scope/, fn ->
      Context.choices(:scope)
    end
  end

  test "a site with no context module opens the editor with no choices, whatever it picks from" do
    put_site!(components: [Billboard.Test.Faq], context: nil)

    assert Context.choices_for(Billboard.Sections.EditorFields.choice_names()) == %{}
  end

  test "a site's bindings say which replace the hero's words, by name or by its string" do
    put_site!(context: Billboard.Test.Context)

    assert Context.replaces_words?(:product)
    assert Context.replaces_words?("product")
    refute Context.replaces_words?(:visit)
    refute Context.replaces_words?(:none)
    assert Context.binding_for("visit") == {:visit, []}
    assert Context.binding_for(:gone) == nil
  end

  test "a site's choices are read by name, several at once for the editor" do
    put_site!(context: Billboard.Test.Context)

    assert %{options: [{"Shoes", "shoes"} | _], every: "Every aisle"} = Context.choices(:scope)
    assert %{scope: %{options: _}} = Context.choices_for([:scope])
  end

  test "a set the site doesn't give is left out of the editor's, and raises read alone" do
    put_site!(context: Billboard.Test.Context)

    assert Map.keys(Context.choices_for([:scope, :gone])) == [:scope]

    assert_raise ArgumentError,
                 ~r/offers no choices called :gone. List :gone in the choice_sets\/0/,
                 fn -> Context.choices(:gone) end
  end
end
