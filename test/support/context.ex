defmodule Billboard.Test.Context do
  @moduledoc """
  What the test site's pages are about: a hero may be bound to a product,
  whose words stand in for its own, or to a visit, which keeps them; and
  a detail may be scoped to one aisle.
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
end
