defmodule Billboard.Test.Context do
  @moduledoc """
  What the test site's pages are about: a hero may be bound to a product,
  whose words stand in for its own, or to a visit, which keeps them; and
  a detail may be scoped to one aisle. The editor draws an item's page
  about the shoes aisle's product, at `/items/shoes`.
  """
  @behaviour Billboard.Context

  @sets [:scope]

  @impl true
  def bindings,
    do: [
      product: [
        note: "The heading comes from the product.",
        link: {"Open the products", "/admin/products"},
        replaces_words: true
      ],
      visit: []
    ]

  @impl true
  def choice_sets, do: @sets

  @impl true
  def choices(:scope),
    do: %{
      options: [{"Shoes", "shoes"}, {"Hats", "hats"}],
      every: "Every aisle",
      none_yet: "There are no aisles yet.",
      gone: "not an aisle now"
    }

  @impl true
  def sample(%{pattern: "/items/:slug"}),
    do: %{
      bindings: %{product: %{heading: "Shoes", eyebrow: "The shoes aisle", lede: "Made *well*."}},
      scope: "shoes"
    }

  def sample(_page), do: %{}

  @impl true
  def path(%{pattern: nil}, _context), do: nil
  def path(%{pattern: "/items/:slug"}, %{scope: scope}), do: "/items/#{scope}"
  def path(%{pattern: "/items/:slug"}, _context), do: nil
  def path(%{pattern: pattern}, _context), do: pattern
end
