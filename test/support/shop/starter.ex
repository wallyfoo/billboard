defmodule Billboard.Test.Shop.Starter do
  @moduledoc """
  The shop's starters. The hero's action on the home page and the
  library's band's action have fixed ids, as a site's starter must, so
  every build agrees. `version!/1`
  raises for the patterns a test lists under
  `Application.get_env(:billboard, :failing_starters)`, standing in for
  a starter whose data can't be read.
  """
  @behaviour Billboard.Starter

  alias Billboard.Test.Shop.{Section, Version}

  @shop_now "8b0f3c4e-2a1d-8e5f-9a6b-1c2d3e4f5a6b"
  @visit "3d7e9a1b-5c2f-4e8d-b6a0-7f1e2d3c4b5a"

  @doc "The id the home page's Shop now action always has."
  def shop_now, do: @shop_now

  @doc "The id the library band's Visit action always has."
  def visit, do: @visit

  @impl true
  def version(pattern), do: %Version{status: :starter, sections: place(sections(pattern))}

  @impl true
  def version!(pattern) do
    if pattern in Application.get_env(:billboard, :failing_starters, []),
      do: raise("the starter for #{inspect(pattern)} can't be read"),
      else: version(pattern)
  end

  defp sections("/") do
    hero =
      build(:hero, %{
        heading: "Everything for the shop",
        actions: [%{label: "Shop now", style: :primary}]
      })

    hero = %{hero | actions: Enum.map(hero.actions, &%{&1 | id: @shop_now})}

    [
      section("hero", :hero, hero),
      section("welcome", :text, build(:text, %{body: "Come in."}), "welcome")
    ]
  end

  defp sections("/about") do
    columns = %{
      section("visit", :columns, build(:columns, %{}))
      | children: [
          section("where", :text, build(:text, %{body: "On the high street."})),
          section("when", :text, build(:text, %{body: "Open every day."}))
        ]
    }

    [hero("About us"), columns]
  end

  defp sections("/items/:slug"), do: [hero("An item")]

  defp sections("/terms"),
    do: [hero("Terms"), section("terms", :text, build(:text, %{body: "Be kind."}))]

  defp sections(nil) do
    band = build(:band, %{heading: "Visit the shop", action: %{label: "Visit"}})
    [section("promo", :band, %{band | action: %{band.action | id: @visit}}, "promo")]
  end

  defp sections(_pattern), do: []

  defp hero(heading), do: section("hero", :hero, build(:hero, %{heading: heading}))
  defp build(type, attrs), do: Billboard.Component.build!(type, attrs)

  defp section(key, type, value, anchor \\ nil),
    do: %Section{
      key: key,
      anchor: anchor,
      content: %Ash.Union{type: type, value: value},
      children: []
    }

  defp place(sections) do
    for {s, i} <- Enum.with_index(sections), do: %{s | position: i, children: place(s.children)}
  end
end
