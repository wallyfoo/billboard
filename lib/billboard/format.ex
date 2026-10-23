defmodule Billboard.Format do
  @moduledoc "Dates and shortened copy, as the stock sections set them."

  @doc ~S|A date as the stock sections write it: "23 October 2026".|
  @spec date(Date.t()) :: String.t()
  def date(%Date{} = date), do: Calendar.strftime(date, "%-d %B %Y")

  @doc """
  Trims copy to `limit` characters at a word boundary, for zones with a
  soft limit. The ellipsis counts toward `limit`. A first word too long
  to fit is cut short.
  """
  @spec trim(String.t(), pos_integer()) :: String.t()
  def trim(text, limit) when is_binary(text) and is_integer(limit) and limit > 0 do
    if String.length(text) <= limit do
      text
    else
      cut = String.slice(text, 0, limit)
      words = String.replace(cut, ~r/\s+\S*$/u, "")

      if words == cut,
        do: String.slice(text, 0, limit - 1) <> "…",
        else: words <> "…"
    end
  end
end
