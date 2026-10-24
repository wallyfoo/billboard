defmodule Billboard.TokensTemplateTest do
  @moduledoc """
  The tokens file mix billboard.install writes sets every token the
  theme reads without a fallback, and names the rest.
  """
  use ExUnit.Case, async: true

  alias Billboard.Test.Theme

  @template Path.expand("../../priv/templates/billboard.install/billboard-tokens.css", __DIR__)
  @theme Path.expand("../../assets/css/theme.css", __DIR__)

  test "sets every token the theme reads with no fallback" do
    template = File.read!(@template)

    for token <- Theme.unfallbacked_tokens(@theme) do
      assert template =~ ~r/^\s*#{Regex.escape(token)}:/m,
             "the starter tokens file doesn't set #{token}"
    end
  end

  test "names every token the theme reads, set or in a comment" do
    template = File.read!(@template)

    for token <- Theme.tokens(@theme) do
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
end
