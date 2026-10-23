defmodule Billboard.Sections.PartsTest do
  @moduledoc """
  How the editor changes each part, and how an action is drawn: a link
  by billboard, every other kind by the site.
  """
  # The site's components and actions are set in application env, which
  # every test reads.
  use ExUnit.Case, async: false

  import Billboard.Test.Env
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Billboard.Sections.Parts

  setup do: put_site!(components: [Billboard.Test.Faq], actions: Billboard.Test.Actions)

  defp has?(html, selector),
    do: html |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.count() > 0

  defp action(action, opts \\ []) do
    render_component(&Parts.action/1, [action: action, ctx: %{}] ++ opts)
  end

  describe "editor_fields(:action)" do
    test "offers the site's kinds, in the site's order, with the link among them" do
      kind = Parts.editor_fields(:action)[:kind]

      assert kind[:options] == [
               {"Visit the shop", :visit},
               {"A page on this site", :link},
               {"Call the shop", :call}
             ]

      assert kind[:only_on] == [visit: [:item]]
    end

    test "hides the words the site writes, the address for all but a link, and the note for all but those" do
      fields = Parts.editor_fields(:action)

      assert fields[:label][:hide_when] == [kind: [:call]]
      assert fields[:path][:hide_when] == [kind: [:visit, :call]]
      assert fields[:fixed_words][:hide_when] == [kind: [:visit, :link]]
    end

    test "hints with the site's words, and the site's example path" do
      fields = Parts.editor_fields(:action)

      assert fields[:label][:hint] == "A visit left blank says “Visit”."
      assert fields[:path][:hint] == "A page on this site, such as /about"
      assert Parts.editor_fields(:link)[:path][:hint] == "A page on this site, such as /about"
    end
  end

  describe "a part with fields left out" do
    test "has the part's fields but those" do
      assert Parts.editor_fields({:detail, except: [:only_for_group]}) ==
               Keyword.delete(Parts.editor_fields(:detail), :only_for_group)

      assert Parts.editor_fields(:detail)[:only_for_group] == [
               as: :choice,
               from: :scope,
               label: "Shows on"
             ]
    end

    test "starts as the part does" do
      assert Parts.blank({:detail, except: [:only_for_group]}) == Parts.blank(:detail)
    end
  end

  describe "action/1" do
    test "draws a link as a text link or a button, by its style" do
      text = action(%{kind: :link, style: :text, label: "More", path: "/about"})
      primary = action(%{kind: :link, style: :primary, label: "More", path: "/about"})
      secondary = action(%{kind: :link, style: :secondary, label: "More", path: "/about"})

      assert has?(text, "a.bb-link[href='/about']")
      refute has?(text, ".bb-button")
      assert has?(primary, "a.bb-button.bg-bb-action[href='/about']")
      assert has?(secondary, "a.bb-button.border-bb-action-2[href='/about']")
    end

    test "hands any other kind to the site, with the prefix for its id" do
      html = action(%{kind: :visit, style: :primary, label: nil}, prefix: "statement")
      assert has?(html, "a.test-visit#statement-visit")
    end

    test "draws nothing for a kind the site no longer offers" do
      html = action(%{kind: :gone, style: :primary, label: "Gone", path: nil})
      refute has?(html, "a")
    end
  end
end
