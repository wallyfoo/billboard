defmodule Billboard.RendererTest do
  @moduledoc "A component's renderer, found by its key, or a message naming the fix."
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Renderer

  setup do: put_site!(components: [Billboard.Test.Faq, Billboard.Test.Note])

  test "is the module the component's `renderer` names" do
    assert Renderer.for!(:faq) == Billboard.Test.FaqRenderer
  end

  test "raises, naming the fix, for a component that names none" do
    assert_raise ArgumentError,
                 ~r/Billboard.Test.Note names no renderer. Add `renderer MySiteWeb.Sections.Name`/,
                 fn -> Renderer.for!(:note) end
  end
end
