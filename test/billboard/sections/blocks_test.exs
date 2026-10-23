defmodule Billboard.Sections.BlocksTest do
  @moduledoc """
  The larger pieces stock sections are drawn from carry their hook
  classes, which have no styles of their own, so a site can decorate
  them in its CSS without replacing a component.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Billboard.Sections.{Blocks, Parts}

  defp has?(html, selector),
    do: html |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.count() > 0

  test "a section's head marks its eyebrow and heading" do
    html =
      render_component(&Parts.head/1,
        head: %{eyebrow: "Hair", heading: "Colour", action: nil},
        ctx: %{}
      )

    assert has?(html, "p.bb-eyebrow")
    assert has?(html, "h2.bb-heading")
  end

  test "a section head nested under another marks its eyebrow and heading" do
    html = render_component(&Blocks.section_head/1, eyebrow: "Hair", heading: "Colour", tag: "h3")

    assert has?(html, "div.bb-section-head.bb-rule-top p.bb-eyebrow")
    assert has?(html, "div.bb-section-head h3.bb-heading")
  end

  test "an empty photograph slot is marked too" do
    html = render_component(&Blocks.photo/1, label: "Hands working")
    assert has?(html, "figure.bb-photo")
  end
end
