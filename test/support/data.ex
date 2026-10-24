defmodule Billboard.Test.Data do
  @moduledoc """
  The shop's data: the reviews and news rows a test puts in its process
  dictionary, under `:shop_reviews` and `:shop_news` (none unless it
  does), the news cut to each section's `limit`. Each read is noted
  there too, so `reads/0` says what a test's pages read, in order.
  """
  @behaviour Billboard.Data

  alias Billboard.Components.{News, Reviews}

  @impl true
  def fetch(%Reviews{}, _context, loaded),
    do: Billboard.Data.once(loaded, :reviews, fn -> read(:reviews, :shop_reviews) end)

  def fetch(%News{limit: limit}, _context, loaded),
    do:
      Billboard.Data.once(loaded, {:news, limit}, fn ->
        {:news, limit} |> read(:shop_news) |> Enum.take(limit)
      end)

  def fetch(_content, _context, _loaded), do: :none

  @doc "What this process's pages have read, in order."
  def reads, do: Enum.reverse(Process.get(:shop_reads, []))

  defp read(what, key) do
    Process.put(:shop_reads, [what | Process.get(:shop_reads, [])])
    Process.get(key, [])
  end
end
