defmodule Billboard.Test.Site do
  @moduledoc """
  A site written by hand against `Billboard.Site`'s required callbacks,
  and the optional answers components and the editor read (its actions,
  context, data, layout, kinds, palette, and example path), for the
  component unit tests, which swap them per test.
  `Billboard.Test.Env.put_site!/1` makes it the site for one test; the
  configured site is `Billboard.Test.Shop`.
  """
  @behaviour Billboard.Site

  @defaults [
    components: [],
    surfaces: [%{name: "plain", label: "Plain"}, %{name: "loud", label: "Loud"}],
    offered: [page: ["plain"], stand_out: ["loud"], card: []],
    options: [],
    rules: [],
    actions: nil,
    context: nil,
    data: nil,
    layout: nil,
    kinds: [],
    palette: [],
    example_path: "/about"
  ]

  @impl true
  def components, do: get(:components)

  @impl true
  def surfaces, do: get(:surfaces)

  @impl true
  def offered, do: get(:offered)

  @impl true
  def options, do: get(:options)

  @impl true
  def rules, do: get(:rules)

  @impl true
  def actions, do: get(:actions)

  @impl true
  def context, do: get(:context)

  @impl true
  def data, do: get(:data)

  @impl true
  def layout, do: get(:layout)

  @impl true
  def kinds, do: get(:kinds)

  @impl true
  def palette, do: get(:palette)

  @impl true
  def example_path, do: get(:example_path)

  defp get(key) do
    :billboard
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get_lazy(key, fn -> Keyword.fetch!(@defaults, key) end)
  end
end
