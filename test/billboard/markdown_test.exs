defmodule Billboard.MarkdownTest do
  @moduledoc "Markdown in the words a site's editors write renders inline, escaped, and typographic."
  use ExUnit.Case, async: true

  alias Billboard.Markdown

  defp html(text, opts \\ []), do: text |> Markdown.inline(opts) |> Phoenix.HTML.safe_to_string()

  describe "inline/2" do
    test "renders bold, italic, and links" do
      assert html("**Cut** and *colour* at [FJ](https://example.com)") ==
               ~s(<strong>Cut</strong> and <em>colour</em> at ) <>
                 ~s(<a href="https://example.com" rel="noopener noreferrer">FJ</a>)
    end

    test "escapes raw HTML instead of rendering it" do
      assert html("<script>alert(1)</script> <b>x</b>") ==
               "&lt;script&gt;alert(1)&lt;/script&gt; &lt;b&gt;x&lt;/b&gt;"
    end

    test "drops javascript: links" do
      refute html("[x](javascript:alert(1))") =~ "javascript"
    end

    test "sets quotes, dashes, and ellipses" do
      assert html(~s("Late" -- it's open...)) == "“Late” – it’s open…"
    end

    test "turns new lines into line breaks, with no paragraph wrapper" do
      assert html("one\ntwo\n\nthree") == "one<br>\ntwo<br>\n<br>\nthree"
    end

    test "keeps the text of block syntax, and list markers" do
      assert html("# Heading\n\n- cut\n- colour") == "Heading<br>\n<br>\n• cut<br>\n• colour"
      assert html("1. Best shop") == "1. Best shop"
    end

    test "renders nil as nothing" do
      assert html(nil) == ""
    end

    test "with a limit, renders copy that fits" do
      assert html("**Book** now", limit: 10) == "<strong>Book</strong> now"
    end

    test "with a limit, trims copy that does not fit and drops its formatting" do
      assert html("**Book** your next cut today", limit: 12) == "Book your…"

      assert html("**Book** your next cut today", limit: 12) ==
               Billboard.Format.trim("Book your next cut today", 12)
    end
  end

  describe "plain/1" do
    test "drops the Markdown" do
      assert Markdown.plain("Room for *everyone*, **always** [here](https://x.y)") ==
               "Room for everyone, always here"
    end

    test "keeps raw HTML as typed" do
      assert Markdown.plain("a <b>b</b>") == "a <b>b</b>"
    end

    test "renders nil as an empty string" do
      assert Markdown.plain(nil) == ""
    end
  end
end
