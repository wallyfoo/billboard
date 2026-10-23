defmodule Billboard.Sections.ButtonsTest do
  @moduledoc "The buttons and links stock sections draw, and the hooks they carry."
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Billboard.Sections.Buttons

  # The one element matching the selector, and its classes as a list.
  defp classes(rendered, selector) do
    [element] =
      rendered
      |> rendered_to_string()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(selector)
      |> Enum.to_list()

    element |> LazyHTML.attribute("class") |> hd() |> String.split()
  end

  test "a primary button fills with the action colour" do
    assigns = %{}

    classes =
      classes(
        ~H"""
        <.bb_button navigate="/book">Book</.bb_button>
        """,
        "a[href='/book']"
      )

    assert "bg-bb-action" in classes
    assert "text-bb-on-action" in classes
    assert "rounded-bb-button" in classes
  end

  test "a secondary button is outlined in the second action colour" do
    assigns = %{}

    classes =
      classes(
        ~H"""
        <.bb_button variant="secondary">More</.bb_button>
        """,
        "button"
      )

    assert "border-bb-action-2" in classes
    assert "text-bb-action-2" in classes
  end

  test "a link takes its tone's colour" do
    assigns = %{}

    accent =
      classes(
        ~H"""
        <.bb_link tone="accent" navigate="/book">Book</.bb_link>
        """,
        "a[href='/book']"
      )

    ink =
      classes(
        ~H"""
        <.bb_link navigate="/">Home</.bb_link>
        """,
        "a[href='/']"
      )

    quiet =
      classes(
        ~H"""
        <.bb_link tone="quiet" navigate="/">Home</.bb_link>
        """,
        "a[href='/']"
      )

    assert "text-bb-accent" in accent
    assert "text-bb-link" in ink
    assert "text-bb-ink-soft" in quiet
  end

  # The hooks let a site decorate a button or a link without replacing
  # the component, and they're on every variant, tone, and element.
  test "a button carries the bb-button hook, as a link or a button" do
    assigns = %{}

    link =
      classes(
        ~H"""
        <.bb_button navigate="/book">Book</.bb_button>
        """,
        "a[href='/book']"
      )

    button =
      classes(
        ~H"""
        <.bb_button variant="secondary">More</.bb_button>
        """,
        "button"
      )

    assert "bb-button" in link
    assert "bb-button" in button
  end

  test "a link carries the bb-link hook, in each tone, compact or not" do
    assigns = %{}

    link =
      classes(
        ~H"""
        <.bb_link tone="quiet" navigate="/">Home</.bb_link>
        """,
        "a[href='/']"
      )

    accent =
      classes(
        ~H"""
        <.bb_link tone="accent" navigate="/book">Book</.bb_link>
        """,
        "a[href='/book']"
      )

    compact =
      classes(
        ~H"""
        <.bb_link compact navigate="/">Home</.bb_link>
        """,
        "a[href='/']"
      )

    assert "bb-link" in link
    assert "bb-link" in accent
    assert "bb-link" in compact
    refute "bb-button" in link
  end
end
