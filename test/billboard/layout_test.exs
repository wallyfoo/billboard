defmodule Billboard.LayoutTest do
  @moduledoc "The site's layout, from its `layout:` answer, and the site's own data it gives."
  # The site is set in application env, which every test reads.
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Layout

  defmodule Bare do
    @moduledoc false
    @behaviour Billboard.Layout
    use Phoenix.Component

    @impl true
    def page(assigns), do: ~H"<main>{render_slot(@inner_block)}</main>"
  end

  test "is the module the site names, with the site's own data" do
    assert Billboard.Test.Shop.layout() == Billboard.Test.Layout
    assert Layout.module!() == Billboard.Test.Layout
    assert Layout.site() == %{name: "The shop"}
  end

  test "gives no data for a layout without site/0" do
    put_site!(layout: Bare)
    assert Layout.site() == %{}
  end

  test "raises, naming the fix, for a site that names none" do
    put_site!(layout: nil)

    assert_raise ArgumentError,
                 ~r/Billboard.Test.Site names no layout. Add `layout: MySiteWeb.Layouts`/,
                 fn -> Layout.module!() end
  end
end
