defmodule Billboard.Sections.Words do
  @moduledoc """
  A section's words, as the renderers draw them. For a visitor, or in a
  section the editor hasn't opened, `text/4` is the words as they always
  were: inline Markdown, or plain text with `markdown: false`. In the open
  section (`ctx[:edit].open` is the key of `ctx[:section]`), it is a
  `contenteditable` span run by the `InlineWords` hook, which sends what
  is typed to the section's editor as `edit_words`, with the field's
  words path (`"head.heading"`, `"points.1.body"`). The hook is
  billboard's, in `assets/js/inline_words.js`, and the site's LiveSocket
  registers it under that name, from `assets/js/billboard.js`, with the
  editor's others.

  `phx-update="ignore"` keeps the server's redraws away from the span
  while it is typed in, so the caret never jumps. Its id is the section's
  key and the path, and never changes while the field is drawn: a new id
  would make LiveView replace the span the admin is typing in on every
  save. The stored words travel in its attributes instead, which LiveView
  still updates on an ignored element: `data-words`, as stored, and
  `data-html`, as a visitor sees them. The hook puts words changed by
  anything but typing (another admin, Discard) into the span.

  In the editor's other sections, the words are as a visitor sees them,
  in a span naming their path (`data-words-at`), so a click on them can
  open the section with the caret where it landed.

  `editing?/1` tells a renderer to draw a field the section leaves out
  when it's empty, such as an optional lede, so it can be typed into.
  """
  use Phoenix.Component

  alias Billboard.Markdown
  alias Billboard.Sections.EditorFields

  @doc "Whether `ctx` is drawing the open section."
  def editing?(%{edit: %{open: key}, section: %{key: key}}) when is_binary(key), do: true
  def editing?(_ctx), do: false

  @doc """
  The DOM id of the words at `path` in the section with key `key`, as the
  open section draws them: `words-KEY-head-heading` for `head.heading`.
  The canvas's and the bar's scripts build it too, so they match it.
  """
  @spec id(String.t(), String.t()) :: String.t()
  def id(key, path), do: "words-#{key}-#{dashed(path)}"

  @doc "A path's dots as dashes, for an id: `head.action` is `head-action`."
  @spec dashed(String.t()) :: String.t()
  def dashed(path), do: String.replace(path, ".", "-")

  @doc """
  The words at `path` in the section `ctx` is drawing, holding `value`.
  Options: `markdown: false` for words stored as plain text, such as a
  quote's name; `placeholder`, what an empty field shows in the editor,
  and the field's name for a screen reader (the spec's label when it's
  left out); `limit`, passed to `Markdown.inline/2` for a visitor, to
  shorten long words (the open section shows them in full).

  A path the section's specs don't name as words raises: a renderer that
  names one is a bug.
  """
  def text(ctx, path, value, opts \\ []) do
    markdown = Keyword.get(opts, :markdown, true)

    cond do
      editing?(ctx) -> editable(ctx, path, value, markdown, opts[:placeholder])
      closed?(ctx) -> marked(path, visitor(value, markdown, Keyword.take(opts, [:limit])))
      true -> visitor(value, markdown, Keyword.take(opts, [:limit]))
    end
  end

  # A section the editor draws, but hasn't opened.
  defp closed?(%{edit: %{}, section: %{}}), do: true
  defp closed?(_ctx), do: false

  defp marked(_path, nil), do: nil

  defp marked(path, words) do
    assigns = %{path: path, words: words}

    ~H"<span data-words-at={@path}>{@words}</span>"
  end

  defp visitor(value, markdown, inline_opts \\ [])
  defp visitor(nil, _markdown, _inline_opts), do: nil
  defp visitor(value, true, inline_opts), do: Markdown.inline(value, inline_opts)
  defp visitor(value, false, _inline_opts), do: value

  # Called by hand from the renderers, so its assigns are built whole here
  # rather than with `assign/3`, which wants a component's assigns. The
  # span keeps no whitespace between its tags and the words, or the caret
  # could land in it and what's typed would gain a space.
  defp editable(%{section: section}, path, value, markdown, placeholder) do
    type = section.content.type

    spec =
      case EditorFields.words(EditorFields.specs(type), path) do
        {:ok, _form_path, spec} -> spec
        :error -> raise ArgumentError, "#{inspect(path)} isn't a words field of #{type}"
      end

    html = visitor(value, markdown)

    assigns = %{
      id: id(section.key, path),
      section_key: section.key,
      path: path,
      limit: spec[:limit],
      markdown: markdown,
      placeholder: placeholder || spec[:label] || "Type here",
      words: value || "",
      html: html,
      # The words as the span holds them, as a string the hook can put
      # into it when the stored words change.
      html_string: html |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    }

    ~H"""
    <span
      id={@id}
      phx-hook="InlineWords"
      phx-update="ignore"
      contenteditable="true"
      role="textbox"
      spellcheck="true"
      aria-label={@placeholder}
      data-section={@section_key}
      data-path={@path}
      data-limit={@limit}
      data-markdown={to_string(@markdown)}
      data-placeholder={@placeholder}
      data-words={@words}
      data-html={@html_string}
      class="bb-inline-words"
    >{@html}</span>
    """
  end
end
