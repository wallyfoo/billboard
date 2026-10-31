defmodule Billboard.DocsTest do
  @moduledoc "The library's words are for any site: no plan's step, and no one site's name."
  use ExUnit.Case, async: true

  @files Path.wildcard("{lib,assets,priv,guides,usage-rules}/**/*.{ex,exs,eex,heex,js,css,md}") ++
           ["README.md", "usage-rules.md", "mix.exs"]

  test "no file names a plan's step" do
    for file <- @files, line <- numbered(file), line.text =~ ~r/\bsteps? \d|\b5[ab]\b/i do
      flunk("#{file}:#{line.n} names a plan's step: #{String.trim(line.text)}")
    end
  end

  test "no file names a real site: Stylish Strands, its palette, or SWAN" do
    for file <- @files,
        line <- numbered(file),
        line.text =~ ~r/stylish|salon|aubergine|brass|mulberry|heather|swan/i do
      flunk("#{file}:#{line.n} names a real site: #{String.trim(line.text)}")
    end
  end

  defp numbered(file) do
    file
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map(fn {text, n} -> %{text: text, n: n} end)
  end
end
