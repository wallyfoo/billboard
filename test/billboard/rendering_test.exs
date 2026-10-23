defmodule Billboard.RenderingTest do
  @moduledoc "Function components render in the library's tests, and LazyHTML reads them."
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  defp greeting(assigns), do: ~H|<p class="bb-probe">Hello, {@name}</p>|

  test "a function component renders, and its markup can be queried" do
    html = render_component(&greeting/1, name: "shop")

    assert html |> LazyHTML.from_fragment() |> LazyHTML.query("p.bb-probe") |> LazyHTML.text() ==
             "Hello, shop"
  end
end
