defmodule Billboard.Test.Site do
  @moduledoc """
  The site the library's tests run against. Each answer can be replaced
  for one test with `Billboard.Test.Env.put_site!/1`, which writes under
  `Application.get_env(:billboard, Billboard.Test.Site)`.
  """
  @behaviour Billboard.Site

  @defaults [
    components: [],
    surfaces: [%{name: "plain", label: "Plain"}, %{name: "loud", label: "Loud"}],
    offered: [page: ["plain"], stand_out: ["loud"], card: []],
    options: [],
    rules: []
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

  defp get(key) do
    :billboard
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get_lazy(key, fn -> Keyword.fetch!(@defaults, key) end)
  end
end
