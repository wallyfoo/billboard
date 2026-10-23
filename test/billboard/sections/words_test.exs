defmodule Billboard.Sections.WordsTest do
  @moduledoc """
  A section's words as the renderers draw them: as a visitor reads them,
  marked in a closed section, and typed into in the open one.
  """
  # The site's components are set in application env, which every test
  # reads.
  use ExUnit.Case, async: false

  import Billboard.Test.Env
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Billboard.Markdown
  alias Billboard.Sections.Words

  setup do: put_site!(components: [Billboard.Test.Faq])

  defp section(key),
    do: Billboard.Test.Render.section(:faq, %{title: "x", questions: [%{question: "Open?"}]}, key)

  defp open(key, open), do: %{edit: %{open: open}, section: section(key)}

  # The one span the open section's words draw.
  defp span(rendered) do
    rendered
    |> rendered_to_string()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("span[contenteditable]")
  end

  defp attr(span, name), do: span |> LazyHTML.attribute(name) |> List.first()

  describe "editing?/1" do
    test "is true only while drawing the open section" do
      assert Words.editing?(open("s1", "s1"))
      refute Words.editing?(open("s2", "s1"))
      refute Words.editing?(open("s1", nil))
      refute Words.editing?(%{section: section("s1")})
      refute Words.editing?(%{})
    end
  end

  describe "text/4 for a visitor" do
    test "is the words as inline Markdown" do
      assert Words.text(%{}, "title", "Room for *everyone*") ==
               Markdown.inline("Room for *everyone*")
    end

    test "is the words themselves with markdown: false" do
      assert Words.text(%{}, "quote.name", "Ana *B*", markdown: false) == "Ana *B*"
    end

    test "is nil for no words" do
      assert Words.text(%{}, "title", nil) == nil
    end

    test "shortens long words with limit:" do
      long = "A long line of words that runs well past the limit"

      assert Words.text(%{}, "intro", long, limit: 20) == Markdown.inline(long, limit: 20)
      refute Words.text(%{}, "intro", long, limit: 20) == Markdown.inline(long)
    end

    test "is the same in a section that isn't open, in a span naming its path" do
      span =
        open("s2", "s1")
        |> Words.text("title", "Room for *everyone*")
        |> rendered_to_string()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("span[data-words-at='title']")

      assert span |> LazyHTML.query("em") |> LazyHTML.text() == "everyone"
      assert LazyHTML.text(span) == "Room for everyone"
      assert span |> LazyHTML.query("[contenteditable]") |> Enum.empty?()
      assert Words.text(open("s2", "s1"), "title", nil) == nil
    end
  end

  describe "text/4 in the open section" do
    test "is a span the hook can type into, holding the words as they read" do
      span = span(Words.text(open("s1", "s1"), "title", "Room for *everyone*"))

      assert LazyHTML.attribute(span, "contenteditable") == ["true"]
      assert attr(span, "phx-hook") == "InlineWords"
      assert attr(span, "phx-update") == "ignore"
      assert attr(span, "data-section") == "s1"
      assert attr(span, "data-path") == "title"
      assert attr(span, "data-limit") == "60"
      assert attr(span, "data-markdown") == "true"
      assert span |> LazyHTML.query("em") |> LazyHTML.text() == "everyone"
      # No whitespace around the words: the caret would land in it.
      assert LazyHTML.text(span) == "Room for everyone"
    end

    test "names its id after the section and the path, whatever the words" do
      ctx = open("s1", "s1")

      id = fn words -> ctx |> Words.text("questions.0.label", words) |> span() |> attr("id") end

      # A new id on every save would replace the span being typed in.
      assert id.("A") == "words-s1-questions-0-label"
      assert id.("A") == id.("B")
      assert id.("A") == Words.id("s1", "questions.0.label")
      assert Words.id("s1", "points.1.body") == "words-s1-points-1-body"
    end

    test "carries the stored words and their rendering in its attributes" do
      span = span(Words.text(open("s1", "s1"), "title", "Room for *everyone*"))

      assert attr(span, "data-words") == "Room for *everyone*"

      assert attr(span, "data-html") ==
               "Room for *everyone*" |> Markdown.inline() |> Phoenix.HTML.safe_to_string()

      empty = span(Words.text(open("s1", "s1"), "intro", nil))

      assert attr(empty, "data-words") == ""
      assert attr(empty, "data-html") == ""
    end

    test "escapes plain words, in the span and in data-html" do
      span = span(Words.text(open("s1", "s1"), "title", "<b>x</b> & co", markdown: false))

      assert span |> LazyHTML.query("b") |> Enum.empty?()
      assert LazyHTML.text(span) == "<b>x</b> & co"
      assert attr(span, "data-words") == "<b>x</b> & co"
      assert attr(span, "data-html") == "&lt;b&gt;x&lt;/b&gt; &amp; co"
    end

    test "has no data-limit for a field with no limit" do
      span = span(Words.text(open("s1", "s1"), "sign_off", "See you"))

      assert attr(span, "data-path") == "sign_off"
      assert LazyHTML.attribute(span, "data-limit") == []
    end

    test "holds plain words with markdown: false" do
      span = span(Words.text(open("s1", "s1"), "title", "*Hi*", markdown: false))

      assert attr(span, "data-markdown") == "false"
      assert LazyHTML.text(span) == "*Hi*"
    end

    test "is empty, with its placeholder, for no words" do
      span = span(Words.text(open("s1", "s1"), "intro", nil, placeholder: "A line or two"))

      assert LazyHTML.text(span) == ""
      assert attr(span, "data-placeholder") == "A line or two"
      assert attr(span, "aria-label") == "A line or two"
    end

    test "is named by its spec's label when it has no placeholder" do
      span = span(Words.text(open("s1", "s1"), "title", "Hi"))

      assert attr(span, "aria-label") == "Title"
      assert attr(span, "data-placeholder") == "Title"
    end

    test "shows the words in full, whatever limit: says" do
      long = "A long line of words that runs well past the limit"
      span = span(Words.text(open("s1", "s1"), "intro", long, limit: 20))

      assert LazyHTML.text(span) == long
    end

    test "refuses a path that isn't a words field" do
      assert_raise ArgumentError, fn -> Words.text(open("s1", "s1"), "nope", "x") end
      assert_raise ArgumentError, fn -> Words.text(open("s1", "s1"), "style", "x") end
    end
  end
end
