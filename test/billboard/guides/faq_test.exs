defmodule Billboard.Guides.FaqTest do
  @moduledoc "The guides' FAQ: drawn open and folded, typed into in place, and warned about."
  use Billboard.Test.DataCase, async: false

  import Billboard.Test.Render

  alias Billboard.Directory
  alias Billboard.Sections.{Parts, Words}

  @questions [%{title: "Do you park?", body: "Behind the shop."}, %{title: "Open late?"}]

  test "draws its title and each question with its answer, open" do
    html = visitor(section(:faq, %{title: "Asked", questions: @questions}))

    assert html =~ "Asked"
    assert html =~ "Do you park?"
    assert html =~ "Behind the shop."
    refute html =~ "<details"
  end

  test "draws no title it hasn't got, but offers one in the open section" do
    untitled = section(:faq, %{questions: @questions})

    refute visitor(untitled) =~ "<h2"
    assert open(untitled) =~ ~s(id="#{Words.id("s1", "title")}")
  end

  test "refuses words past their caps" do
    long = String.duplicate("a", 161)

    assert {:error, _error} =
             Billboard.Component.build(:faq, %{title: "Asked", questions: [%{title: long}]})

    assert {:error, _error} =
             Billboard.Component.build(:faq, %{
               title: String.duplicate("a", 121),
               questions: @questions
             })
  end

  test "folds its answers when asked, but never in the open section" do
    folded = section(:faq, %{title: "Asked", style: :folded, questions: @questions})

    assert visitor(folded) =~ "<details"
    refute open(folded) =~ "<details"
  end

  test "types its title and each question's words in place" do
    html = open(section(:faq, %{title: "Asked", questions: @questions}))

    for path <- ~w(title questions.0.title questions.0.body questions.1.title) do
      assert html =~ ~s(id="#{Words.id("s1", path)}"), "no words in place at #{path}"
    end
  end

  test "warns of a question with no answer, and holds nothing back" do
    page = Directory.fetch!("/about")
    # The shop's pages open with a hero, which a page without one is told.
    hero = section(:hero, %{heading: "Welcome"}, "hero")
    faq = section(:faq, %{title: "Asked", questions: @questions})

    assert [%{level: :warning, message: "a question has no answer yet"}] =
             Enum.filter(Billboard.Rules.check(page, [hero, faq], %{}), &(&1.key == "s1"))
  end

  test "an added question starts as the part's blank, which builds" do
    blank = Parts.blank(MySite.Sections.Faq.Question)

    assert {:ok, %{questions: [%{title: "Your question"}]}} =
             Billboard.Component.build(:faq, %{title: "Asked", questions: [blank]})
  end

  test "its glyph draws" do
    assert glyph(section(:faq, %{title: "Asked", questions: @questions})) =~ "bg-bb-glyph-ink"
  end
end
