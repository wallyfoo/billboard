defmodule Billboard.Editor.ComponentsTest do
  @moduledoc """
  The editor's own buttons, inputs, messages, and icon, drawn from the
  editor's tokens and never the theme's.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Billboard.Editor.Components
  alias Billboard.Test.ClassWords

  defp doc(html), do: LazyHTML.from_fragment(html)

  defp has?(doc, selector), do: LazyHTML.query(doc, selector) |> Enum.count() > 0

  defp text(doc, selector),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim()

  defp button(attrs) do
    assigns = %{attrs: attrs}

    ~H"""
    <Components.button {@attrs}>Publish</Components.button>
    """
    |> rendered_to_string()
  end

  defp field(errors, value \\ "Hello") do
    %Phoenix.HTML.FormField{
      id: "section_heading",
      name: "section[heading]",
      field: :heading,
      errors: errors,
      value: value,
      form: Phoenix.Component.to_form(%{"heading" => value}, as: :section)
    }
  end

  # The theme's colours, type roles, corners, measures, wrap, card,
  # hairline, and custom properties, which the site sets and the editor's
  # controls never draw with: each has an editor token of its own, or no
  # place in the editor.
  defp site_words(html) do
    html
    |> String.replace("&quot;", "\"")
    |> ClassWords.words()
    |> Enum.filter(fn word ->
      String.starts_with?(word, ["bb-type-", "rounded-bb-"]) or
        (String.starts_with?(word, "--bb-") and not String.starts_with?(word, "--bb-edit-")) or
        ClassWords.colour?(word, ClassWords.theme_colours()) or
        word in ~w(ease-bb duration-bb bb-card bb-wrap bb-measure bb-measure-title bb-section-pad
                   bb-rule-top)
    end)
    |> Enum.uniq()
  end

  # The editor's own focus ring, in its blue: the theme's is drawn in the
  # surface's focus colour, which is all but invisible on some surfaces.
  @ring Enum.map_join(~w(outline-2 outline-offset-2 outline-bb-edit), &".focus-visible\\:#{&1}")

  describe "button/1" do
    test "draws a button in the primary skin, from the editor's tokens" do
      html = button(%{id: "go", type: "button"})
      doc = doc(html)

      assert has?(
               doc,
               "button#go[type='button'].bb-edit-type-button.bg-bb-edit-ink.text-bb-edit-paper"
             )

      assert has?(doc, "button#go.hover\\:bg-bb-edit-ink-strong")
      assert text(doc, "button#go > span") == "Publish"
      assert site_words(html) == []
    end

    test "draws the secondary skin as an outline" do
      html = button(%{id: "go", variant: "secondary"})
      doc = doc(html)

      assert has?(doc, "button#go.border-bb-edit-secondary.bg-transparent.text-bb-edit-secondary")
      assert has?(doc, "button#go.hover\\:bg-bb-edit-secondary.hover\\:text-bb-edit-paper")
      assert site_words(html) == []
    end

    test "draws a link with navigate" do
      html = button(%{id: "go", navigate: "/admin/pages"})
      doc = doc(html)

      assert has?(doc, "a#go[href='/admin/pages'][data-phx-link='redirect'].bb-edit-type-button")
      refute has?(doc, "button")
      assert site_words(html) == []
    end

    test "draws a disabled button, greyed by the editor's tokens" do
      html = button(%{id: "go", disabled: true})
      doc = doc(html)

      assert has?(
               doc,
               "button#go[disabled].disabled\\:bg-bb-edit-line.disabled\\:text-bb-edit-disabled"
             )

      assert site_words(html) == []
    end

    test "rings a focused button or link in the editor's blue" do
      assert has?(doc(button(%{id: "go"})), "button#go#{@ring}")
      assert has?(doc(button(%{id: "go", variant: "secondary"})), "button#go#{@ring}")
      assert has?(doc(button(%{id: "go", navigate: "/admin/pages"})), "a#go#{@ring}")
    end
  end

  describe "input/1" do
    test "draws a text field with its label and hint" do
      html =
        render_component(&Components.input/1,
          field: field([]),
          label: "Heading",
          hint: "A few words"
        )

      doc = doc(html)

      assert has?(doc, "label[for='section_heading'].bb-edit-type-label.text-bb-edit-soft")

      assert has?(
               doc,
               "input#section_heading[type='text'][name='section[heading]'][value='Hello']"
             )

      assert has?(doc, "input#section_heading.border-bb-edit-faint.text-bb-edit-ink")
      assert text(doc, "p.bb-edit-type-small.text-bb-edit-soft") == "A few words"
      assert site_words(html) == []
    end

    test "draws a field's errors in place of its hint, translated" do
      errors = [{"is required", []}, {"at most %{count}", [count: 3]}]

      html =
        render_component(&Components.input/1,
          id: "heading",
          name: "heading",
          value: "",
          label: "Heading",
          hint: "A few words",
          errors: Enum.map(errors, &Components.translate_error/1)
        )

      doc = doc(html)

      assert doc |> LazyHTML.query("p.text-bb-edit-error") |> Enum.map(&LazyHTML.text/1) ==
               ["is required", "at most 3"]

      assert has?(doc, "input#heading.border-bb-edit-error")
      refute has?(doc, "p.text-bb-edit-soft")
      assert site_words(html) == []
    end

    test "draws a used field's errors from its form, translated" do
      form =
        to_form(%{"heading" => "Far too long"},
          as: :section,
          errors: [heading: {"at most %{count}", [count: 3]}]
        )

      html = render_component(&Components.input/1, field: form[:heading], label: "Heading")
      doc = doc(html)

      assert text(doc, "p.text-bb-edit-error") == "at most 3"
      assert has?(doc, "input#section_heading.border-bb-edit-error")
    end

    test "draws a select with its options" do
      html =
        render_component(&Components.input/1,
          id: "variant",
          name: "variant",
          type: "select",
          label: "Layout",
          value: "right",
          options: [{"Photo right", "right"}, {"Photo left", "left"}]
        )

      doc = doc(html)

      assert has?(doc, "label[for='variant'].bb-edit-type-label")
      assert has?(doc, "select#variant[name='variant'].appearance-none")
      assert has?(doc, "select#variant option[value='right'][selected]")
      assert has?(doc, "select#variant option[value='left']")
      assert site_words(html) == []
    end

    test "draws a textarea with its words" do
      html =
        render_component(&Components.input/1,
          id: "body",
          name: "body",
          type: "textarea",
          label: "Body",
          value: "Some words"
        )

      doc = doc(html)

      assert has?(doc, "textarea#body[name='body'].resize-y")
      assert text(doc, "textarea#body") == "Some words"
      assert site_words(html) == []
    end

    test "draws a checkbox with its label" do
      html =
        render_component(&Components.input/1,
          id: "shown",
          name: "shown",
          type: "checkbox",
          label: "Shown",
          value: true
        )

      doc = doc(html)

      assert has?(doc, "input[type='hidden'][name='shown'][value='false']")
      assert has?(doc, "input#shown[type='checkbox'][value='true'][checked].accent-bb-edit-ink")
      assert text(doc, "label span.text-bb-edit-ink") == "Shown"
      assert site_words(html) == []
    end

    test "rings a focused checkbox in the editor's blue" do
      html =
        render_component(&Components.input/1, id: "shown", name: "shown", type: "checkbox")

      assert has?(doc(html), "input#shown[type='checkbox']#{@ring}")
    end

    test "marks a focused field by its underline, in the editor's blue, with no ring" do
      for type <- ~w(text select textarea) do
        html =
          render_component(&Components.input/1,
            id: "heading",
            name: "heading",
            type: type,
            value: "",
            options: []
          )

        assert has?(
                 doc(html),
                 "#heading.border-bb-edit-faint.not-placeholder-shown\\:border-bb-edit-ink" <>
                   ".focus\\:border-bb-edit.focus-visible\\:outline-none"
               ),
               type
      end
    end

    # Tailwind sorts a variant's rule after a plain one, so a field with a
    # problem names no other underline, which would outweigh its own.
    test "keeps a field's error underline, focused or holding words" do
      for type <- ~w(text select textarea) do
        html =
          render_component(&Components.input/1,
            id: "heading",
            name: "heading",
            type: type,
            value: "Far too long",
            options: [],
            errors: ["at most 3"]
          )

        doc = doc(html)
        assert has?(doc, "#heading.border-bb-edit-error.focus-visible\\:outline-none"), type

        assert html |> ClassWords.words() |> Enum.filter(&String.contains?(&1, "border-bb-")) ==
                 ["border-bb-edit-error"],
               type
      end
    end
  end

  describe "the theme check" do
    test "finds the theme's names in what it reads" do
      html =
        ~s|<p class="bb-type-body text-bb-ink rounded-bb-card ease-bb hover:bg-bb-accent/40 bb-wrap
           bb-card bb-measure bb-measure-title bb-section-pad bb-rule-top
           duration-[var(--bb-duration)] pl-[var(--bb-gutter)] bb-edit-type-body
           duration-[var(--bb-edit-duration)]">|

      assert site_words(html) ==
               ~w(bb-type-body text-bb-ink rounded-bb-card ease-bb bg-bb-accent bb-wrap bb-card
                  bb-measure bb-measure-title bb-section-pad bb-rule-top --bb-duration
                  --bb-gutter)
    end
  end

  describe "translate_error/1" do
    test "fills a message's names from its options" do
      assert Components.translate_error({"is required", []}) == "is required"
      assert Components.translate_error({"at most %{count}", [count: 3]}) == "at most 3"

      assert Components.translate_error({"%{a} and %{b}", [a: "one", b: :two]}) == "one and two"
    end
  end

  describe "flash_group/1" do
    test "draws an info and an error message, and the connection's" do
      html =
        render_component(&Components.flash_group/1,
          flash: %{"info" => "Published.", "error" => "Not saved."}
        )

      doc = doc(html)

      assert has?(doc, "#flash-group[aria-live='polite']")
      assert text(doc, "#flash-info[role='alert'] p") == "Published."
      assert has?(doc, "#flash-info .border-l-bb-edit-ink")
      assert text(doc, "#flash-error p.text-bb-edit-error") == "Not saved."
      assert has?(doc, "#flash-error .border-l-bb-edit-error")
      assert has?(doc, "#client-error[hidden]")
      assert has?(doc, "#server-error[hidden]")
      assert text(doc, "#client-error p.bb-edit-type-label") == "Connection lost"
      assert text(doc, "#server-error p.bb-edit-type-label") == "Something went wrong"
      assert has?(doc, "#flash-info button[aria-label='close'] .hero-x-mark")
      assert site_words(html) == []
    end

    test "draws no message when there's none" do
      doc = doc(render_component(&Components.flash_group/1, flash: %{}))

      refute has?(doc, "#flash-info")
      refute has?(doc, "#flash-error")
      assert has?(doc, "#client-error")
    end
  end

  describe "icon/1" do
    test "draws a Heroicon" do
      doc = doc(render_component(&Components.icon/1, name: "hero-x-mark-mini", class: "size-3"))

      assert has?(doc, "span.hero-x-mark-mini.size-3[aria-hidden='true']")
    end
  end
end
