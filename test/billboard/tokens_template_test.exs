defmodule Billboard.TokensTemplateTest do
  @moduledoc """
  The tokens file mix billboard.install writes sets every token the
  theme, the editor's styles, and the sections read without a fallback,
  and names the rest, on paper in both of phx.new's themes.
  """
  use ExUnit.Case, async: true

  alias Billboard.Test.Theme

  @template Path.expand("../../priv/templates/billboard.install/billboard-tokens.css", __DIR__)

  test "sets every token billboard reads with no fallback" do
    template = File.read!(@template)

    for token <- Theme.site_unfallbacked_tokens() do
      assert template =~ ~r/^\s*#{Regex.escape(token)}:/m,
             "the starter tokens file doesn't set #{token}"
    end
  end

  test "names every token billboard reads, set or in a comment" do
    template = File.read!(@template)

    for token <- Theme.site_tokens() do
      assert template =~ ~r/#{Regex.escape(token)}(?![\w-])/,
             "the starter tokens file never mentions #{token}"
    end
  end

  test "sets all nine noise tokens, which have no fallback" do
    template = File.read!(@template)

    for n <- 1..9 do
      assert template =~ ~r/^\s*--bb-noise-#{n}:/m,
             "the starter tokens file doesn't set --bb-noise-#{n}"
    end
  end

  test "draws the surfaces the generated site names, and safelists them" do
    template = File.read!(@template)

    assert template =~ "@utility bb-surface-paper"
    assert template =~ "@utility bb-surface-band"
    assert template =~ ~s|@source inline("bb-surface-{paper,band}");|
  end

  test "sets on paper every token the band changes, so paper inside the band puts it back" do
    template = File.read!(@template)
    [_, paper] = Regex.run(~r/:root,\s*\.bb-surface-paper\s*\{(.*?)\n\}/s, template)
    [_, band] = Regex.run(~r/@utility bb-surface-band\s*\{(.*?)\n\}/s, template)

    for [_, token] <- Regex.scan(~r/^\s*(--bb-[a-z0-9-]+):/m, band) do
      assert paper =~ ~r/^\s*#{Regex.escape(token)}:/m,
             "paper doesn't set #{token}, which the band does"
    end
  end

  test "sets on dark paper every token light paper sets, both ways phx.new asks for dark" do
    template = File.read!(@template)
    [_, paper] = Regex.run(~r/:root,\s*\.bb-surface-paper\s*\{(.*?)\n\}/s, template)

    [_, picked] =
      Regex.run(
        ~r/\[data-theme=dark\],\s*\[data-theme=dark\] \.bb-surface-paper\s*\{(.*?)\n\}/s,
        template
      )

    [_, system] =
      Regex.run(
        ~r/@media \(prefers-color-scheme: dark\) \{\s*:root:not\(\[data-theme\]\),\s*:root:not\(\[data-theme\]\) \.bb-surface-paper\s*\{(.*?)\n  \}/s,
        template
      )

    placeholder = ~w(--bb-placeholder --bb-placeholder-ink --bb-placeholder-chip)

    for token <- set_tokens(paper) ++ placeholder do
      assert token in set_tokens(picked), "dark paper doesn't set #{token}"
    end

    assert "--paper-ground" in set_tokens(picked),
           "dark paper paints no ground, so paper inside the band is white under light words"

    assert declarations(picked) == declarations(system),
           "the data-theme=dark block and the prefers-color-scheme one differ"
  end

  test "gives the placeholder's label a ground of its own, which the band doesn't change" do
    template = File.read!(@template)
    [_, band] = Regex.run(~r/@utility bb-surface-band\s*\{(.*?)\n\}/s, template)

    assert template =~ ~r/^:root \{[^}]*^\s*--bb-placeholder-chip: #ffffff;/ms
    assert template =~ ~r/^:root \{[^}]*^\s*--bb-placeholder-ink: /ms
    refute "--bb-placeholder-chip" in set_tokens(band)
  end

  defp set_tokens(block),
    do: for([_, token] <- Regex.scan(~r/^\s*(--[a-z0-9-]+):/m, block), do: token)

  defp declarations(block) do
    for line <- String.split(block, "\n"),
        line = String.trim(line),
        String.starts_with?(line, "--"),
        do: line
  end
end
