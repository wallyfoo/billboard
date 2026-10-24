defmodule Billboard.Test.Theme do
  @moduledoc """
  Reads CSS, or the code that draws with it, for the `--bb-*` tokens it
  reads, for the tests that check the starter tokens file, the guides,
  and the usage rules against the theme.
  """

  @root Path.expand("../..", __DIR__)

  @doc """
  The files that read the tokens a site sets: the theme, the editor's
  styles, and the sections, whose classes read some tokens straight
  (`pt-[var(--bb-rule-gap,1.5rem)]`).
  """
  def site_reads do
    [
      Path.join(@root, "assets/css/theme.css"),
      Path.join(@root, "assets/css/editor.css"),
      Path.join(@root, "lib/billboard/sections.ex")
      | Path.wildcard(Path.join(@root, "lib/billboard/sections/**/*.ex"))
    ]
  end

  @doc "Every `--bb-*` token `paths` (one or a list) read in a `var(…)`, sorted and unique."
  def tokens(paths) do
    ~r/var\(\s*(--bb-[a-z0-9-]+)/
    |> Regex.scan(read(paths))
    |> Enum.map(fn [_, token] -> token end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  The tokens `paths` (one or a list) read at least once with no
  fallback, as `var(--bb-x)`, and never set themselves: a site must set
  each.
  """
  def unfallbacked_tokens(paths) do
    text = read(paths)

    set =
      ~r/(?<![\w-])(--bb-[a-z0-9-]+)\s*:/
      |> Regex.scan(text)
      |> MapSet.new(fn [_, token] -> token end)

    ~r/var\(\s*(--bb-[a-z0-9-]+)\s*\)/
    |> Regex.scan(text)
    |> Enum.map(fn [_, token] -> token end)
    |> Enum.uniq()
    |> Enum.reject(&MapSet.member?(set, &1))
    |> Enum.sort()
  end

  @doc """
  The tokens a site's tokens file sets or names: those `site_reads/0`
  read, but the editor's own `--bb-edit-*`, which `editor.css` sets.
  """
  def site_tokens, do: Enum.reject(tokens(site_reads()), &editor_own?/1)

  @doc "Of `site_tokens/0`, those read with no fallback and set nowhere billboard draws."
  def site_unfallbacked_tokens,
    do: Enum.reject(unfallbacked_tokens(site_reads()), &editor_own?/1)

  defp read(paths), do: paths |> List.wrap() |> Enum.map_join("\n", &File.read!/1)

  defp editor_own?(token), do: String.starts_with?(token, "--bb-edit-")
end
