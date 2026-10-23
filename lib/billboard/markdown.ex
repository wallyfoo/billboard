defmodule Billboard.Markdown do
  @moduledoc """
  Markdown in the words a site's editors write, rendered with MDEx.

  Editors write **bold**, *italic*, [links](https://…), and line breaks.
  Quotes, dashes, and ellipses come out typographic. Raw HTML shows as typed
  and is never rendered.

  Copy sits inside the page's own headings and paragraphs, so rendering is
  inline only: a new line is a line break, a blank line is two, and block
  syntax such as headings, lists, and quotes keeps only its text.
  """

  @options [
    parse: [smart: true],
    extension: [autolink: true],
    render: [escape: true, hardbreaks: true],
    sanitize: MDEx.Document.default_sanitize_options()
  ]

  @doc """
  A one-line reminder of the syntax, for the hint under a field.
  """
  def hint, do: "Markdown: **bold**, *italic*, and [links](https://…)."

  @doc """
  Renders `text` as inline HTML. With `limit: n`, copy that reads longer than
  `n` characters is trimmed at a word boundary and shown without formatting.
  """
  def inline(text, opts \\ [])

  def inline(nil, _opts), do: Phoenix.HTML.raw("")

  def inline(text, opts) when is_binary(text) do
    case opts[:limit] do
      limit when is_integer(limit) ->
        plain = plain(text)

        if String.length(plain) > limit,
          do: plain |> Billboard.Format.trim(limit) |> Phoenix.HTML.html_escape(),
          else: render(text)

      nil ->
        render(text)
    end
  end

  @doc """
  The copy as a reader sees it, without its Markdown. Soft limits count this,
  not the raw text.
  """
  def plain(nil), do: ""

  def plain(text) when is_binary(text) do
    text
    |> inline_nodes()
    |> Enum.map_join(&plain_node/1)
  end

  defp render(text) do
    doc = parse(text)

    %{doc | nodes: flatten(doc.nodes)}
    |> MDEx.to_html!(@options)
    |> String.trim_trailing()
    |> Phoenix.HTML.raw()
  end

  defp inline_nodes(text), do: text |> parse() |> Map.fetch!(:nodes) |> flatten()

  defp parse(text), do: MDEx.parse_document!(text, @options)

  # Each top-level block becomes a run of inline nodes, the runs joined by a
  # blank line's worth of line breaks.
  defp flatten(blocks) do
    blocks
    |> Enum.map(&inlines/1)
    |> Enum.reject(&(&1 == []))
    |> Enum.intersperse([%MDEx.LineBreak{}, %MDEx.LineBreak{}])
    |> List.flatten()
  end

  defp inlines(%MDEx.Paragraph{nodes: nodes}), do: nodes
  defp inlines(%MDEx.Heading{nodes: nodes}), do: nodes
  defp inlines(%MDEx.CodeBlock{literal: literal}), do: text_lines(literal)
  defp inlines(%MDEx.HtmlBlock{literal: literal}), do: text_lines(literal)
  defp inlines(%MDEx.ThematicBreak{}), do: []

  # List items keep their marker as text, so "1. Cut" still reads "1. Cut".
  defp inlines(%MDEx.List{nodes: items} = list) do
    items
    |> Enum.with_index(list.start)
    |> Enum.map(fn {item, n} -> [%MDEx.Text{literal: marker(list, n)} | inlines(item)] end)
    |> Enum.intersperse([%MDEx.LineBreak{}])
    |> List.flatten()
  end

  defp inlines(%{nodes: blocks}) do
    blocks
    |> Enum.map(&inlines/1)
    |> Enum.reject(&(&1 == []))
    |> Enum.intersperse([%MDEx.LineBreak{}])
    |> List.flatten()
  end

  defp marker(%{list_type: :bullet}, _n), do: "• "
  defp marker(%{delimiter: :paren}, n), do: "#{n}) "
  defp marker(_list, n), do: "#{n}. "

  defp text_lines(literal) do
    literal
    |> String.trim_trailing("\n")
    |> String.split("\n")
    |> Enum.map(&%MDEx.Text{literal: &1})
    |> Enum.intersperse(%MDEx.LineBreak{})
  end

  defp plain_node(%MDEx.Text{literal: literal}), do: literal
  defp plain_node(%MDEx.Code{literal: literal}), do: literal
  defp plain_node(%MDEx.HtmlInline{literal: literal}), do: literal
  defp plain_node(%MDEx.SoftBreak{}), do: "\n"
  defp plain_node(%MDEx.LineBreak{}), do: "\n"
  defp plain_node(%{nodes: nodes}), do: Enum.map_join(nodes, &plain_node/1)
  defp plain_node(_node), do: ""
end
