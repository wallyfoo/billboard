defmodule Billboard.Test.Theme do
  @moduledoc """
  Reads a CSS file for the `--bb-*` tokens it reads, for the tests that
  check the starter tokens file, the guides, and the usage rules against
  the theme.
  """

  @doc "Every `--bb-*` token `path` reads in a `var(…)`, sorted and unique."
  def tokens(path) do
    ~r/var\(\s*(--bb-[a-z0-9-]+)/
    |> Regex.scan(File.read!(path))
    |> Enum.map(fn [_, token] -> token end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  The tokens `path` reads at least once with no fallback, as
  `var(--bb-x)`, and never sets itself: a site must set each.
  """
  def unfallbacked_tokens(path) do
    css = File.read!(path)

    set =
      ~r/(?<![\w-])(--bb-[a-z0-9-]+)\s*:/
      |> Regex.scan(css)
      |> MapSet.new(fn [_, token] -> token end)

    ~r/var\(\s*(--bb-[a-z0-9-]+)\s*\)/
    |> Regex.scan(css)
    |> Enum.map(fn [_, token] -> token end)
    |> Enum.uniq()
    |> Enum.reject(&MapSet.member?(set, &1))
    |> Enum.sort()
  end
end
