defmodule Billboard.Test.Guides do
  @moduledoc """
  Reads the guides' code blocks and their markers, and the regions of
  library files they quote, for `guides_test.exs` and the integration
  check.

  A block's marker is the HTML comment on the line before its opening
  fence, blank lines between allowed: `<!-- from: PATH -->`,
  `<!-- from: PATH#NAME -->`, `<!-- site: PATH -->`, `<!-- run -->`,
  `<!-- fails -->`, or `<!-- sketch -->`. ExDoc doesn't draw it. A
  `text` block needs none, by design: it's what a command prints, or
  the message a failing example gives, and holds no code to check.

  The guides fence code with three backticks, at the margin or inside a
  list item, and nothing else. Every other way ExDoc draws code is read
  too, with its `fence`, so the check can refuse it rather than miss it:
  a fence of tildes or more backticks; one inside a blockquote or on a
  list item's own line (`"> ```"`, `"- ```"`); a block indented four
  spaces (a tab counts as four) after any line but a paragraph's; a line
  of a list item indented four past the item's words; and raw `<pre>`.

  A region of a file is the lines between a start line and an end line,
  in the file's own comments: `# guide:NAME` and `# guide:end` in Elixir,
  `/* guide:NAME */` and `/* guide:end */` in CSS, and
  `<%!-- guide:NAME --%>` and `<%!-- guide:end --%>` in a template.
  """

  alias Billboard.Test.Guides.Block

  @root Path.expand("../..", __DIR__)

  @marker ~r/^<!-- (from|site|run|fails|sketch)(?::\s*(\S*))? -->$/

  # A region's start or end line, in any of the three comment forms.
  @region ~r/^(?:# guide:(\S+)|\/\* guide:(\S+) \*\/|<%!-- guide:(\S+) --%>)$/

  # A list item's first line: its indent, its marker, and the spaces
  # after it, which together are the column its words start at.
  @list_item ~r/^( {0,3})([-*+]|\d+[.)])( +|$)/

  # Where a fence may sit other than the margin: after a blockquote's
  # `>`s, or a list item's marker, on the same line.
  @fence_prefix ~r/^((?:\s*>)+\s?|\s{0,3}(?:[-*+]|\d+[.)])\s+)/

  @doc "Every guide, in the order `mix docs` lists them."
  def guides do
    Mix.Project.config()[:docs][:extras] |> Enum.filter(&String.starts_with?(&1, "guides/"))
  end

  @doc "The blocks of `guide`, a path from the library's root, in order."
  def blocks(guide), do: guide |> Path.expand(@root) |> File.read!() |> parse(guide)

  @doc "The blocks of `text`, a guide's Markdown, as if it were `guide`."
  def parse(text, guide) do
    text
    |> String.split("\n")
    |> Enum.map(&String.replace(&1, "\t", "    "))
    |> Enum.with_index(1)
    |> collect(%{guide: guide, marker: nil, prev: :other, list: nil}, [])
  end

  # Outside a block: a marker is held until the next fence, across blank
  # lines, and any other line drops it. `prev` is what the line before
  # was, `:blank`, `:para` (a paragraph's, or a list item's words), or
  # `:other` (a heading, a comment, a fence's end, or the start), since
  # an indented line after a paragraph's carries the paragraph on, and
  # after anything else is code. `list` is the column an open list
  # item's words start at, or nil.
  defp collect([], _state, acc), do: Enum.reverse(acc)

  defp collect([{line, n} | rest] = lines, state, acc) do
    trimmed = String.trim(line)
    indent = String.length(line) - String.length(String.trim_leading(line))

    cond do
      match = Regex.run(@marker, trimmed) ->
        [_, kind | arg] = match
        arg = if arg in [[], [""]], do: nil, else: hd(arg)
        # One of the five kinds the regex names, so the atom is safe.
        state = %{state | marker: {String.to_atom(kind), arg}, prev: :other, list: nil}
        collect(rest, state, acc)

      String.contains?(String.downcase(line), "<pre") ->
        acc = [block(state, n, "", [line], :pre) | acc]
        collect(rest, %{state | marker: nil, prev: :other}, acc)

      opened = opening_fence(line) ->
        {prefix, fence} = opened

        lang =
          line
          |> String.replace_prefix(prefix, "")
          |> String.trim()
          |> String.trim_leading(String.first(fence))
          |> String.trim()

        {body, rest} = fenced(rest, fence)
        acc = [block(state, n, lang, body, String.trim("#{String.trim(prefix)} #{fence}")) | acc]
        collect(rest, %{state | marker: nil, prev: :other}, acc)

      trimmed == "" ->
        collect(rest, %{state | prev: :blank}, acc)

      state.list && indent >= state.list + 4 ->
        {body, rest} = indented(lines, state.list + 4)
        acc = [block(state, n, "", body, :indented) | acc]
        collect(rest, %{state | marker: nil, prev: :other}, acc)

      is_nil(state.list) and indent >= 4 and state.prev != :para ->
        {body, rest} = indented(lines, 4)
        acc = [block(state, n, "", body, :indented) | acc]
        collect(rest, %{state | marker: nil, prev: :other}, acc)

      trimmed =~ ~r/^\#{1,6}(\s|$)/ or trimmed =~ ~r/^<!--.*-->$/ ->
        collect(rest, %{state | marker: nil, prev: :other, list: nil}, acc)

      item = Regex.run(@list_item, line) ->
        [_, lead, mark, gap] = item
        column = String.length(lead) + String.length(mark) + max(String.length(gap), 1)
        collect(rest, %{state | marker: nil, prev: :para, list: column}, acc)

      true ->
        # A list stays open over its item's indented lines, and over a
        # paragraph's lazy lines; anything else at the margin closes it.
        list = if state.list && (indent >= state.list or state.prev == :para), do: state.list
        collect(rest, %{state | marker: nil, prev: :para, list: list}, acc)
    end
  end

  defp block(state, line, lang, body, fence) do
    {kind, arg} = state.marker || {nil, nil}

    %Block{
      guide: state.guide,
      line: line,
      lang: lang,
      text: Enum.join(body, "\n"),
      marker: kind,
      arg: arg,
      fence: fence
    }
  end

  # The fence a line opens, three or more backticks or tildes, and what
  # comes before it on the line: an indent, or a blockquote's `>` or a
  # list item's marker, which the guides never put a fence after.
  defp opening_fence(line) do
    prefix =
      case Regex.run(@fence_prefix, line) do
        [prefix | _] -> prefix
        nil -> line |> String.split(~r/[^\s]/, parts: 2) |> hd()
      end

    case Regex.run(~r/^(`{3,}|~{3,})/, String.replace_prefix(line, prefix, "")) do
      [_, fence] -> {if(String.trim(prefix) == "", do: "", else: prefix), fence}
      nil -> nil
    end
  end

  # A fenced block's lines, until the fence that closes it: the same
  # character, at least as many times, alone on its line.
  defp fenced(lines, fence) do
    {body, rest} = Enum.split_while(lines, fn {line, _n} -> not closing_fence?(line, fence) end)
    {Enum.map(body, &elem(&1, 0)), Enum.drop(rest, 1)}
  end

  # A blockquote's lines carry its `>`s, which come off first.
  defp closing_fence?(line, fence) do
    char = String.first(fence)
    line = String.replace(line, ~r/^(?:\s*>)+/, "")
    String.trim(line) =~ ~r/^#{Regex.escape(char)}{#{byte_size(fence)},}$/
  end

  # An indented block's lines: while each is blank or `depth` spaces in,
  # less the blank lines it ends with.
  defp indented(lines, depth) do
    pad = String.duplicate(" ", depth)

    {body, rest} =
      Enum.split_while(lines, fn {line, _n} ->
        String.trim(line) == "" or String.starts_with?(line, pad)
      end)

    {trailing, body} =
      body |> Enum.reverse() |> Enum.split_while(&(String.trim(elem(&1, 0)) == ""))

    {body |> Enum.reverse() |> Enum.map(&elem(&1, 0)), Enum.reverse(trailing) ++ rest}
  end

  @doc """
  The paths a `from:` block may quote: what the test env compiles, and
  the templates and assets the library's tests read.
  """
  def quotable, do: Mix.Project.config()[:elixirc_paths] ++ ["priv/templates", "assets"]

  @doc """
  A library file, its region lines dropped, or a region of one
  (`path#name`), dedented, as a guide shows it. Raises, naming the fix,
  when the file or the region isn't there, or the file is one the
  library neither compiles nor tests.
  """
  def source(ref) do
    {path, region} =
      case String.split(ref, "#", parts: 2) do
        [path, name] -> {path, name}
        [path] -> {path, nil}
      end

    full = Path.expand(path, @root)

    unless File.regular?(full) do
      raise ArgumentError, "a guide quotes #{path}, which isn't in the library"
    end

    # By where the path leads, so `lib/../README.md` is README.md.
    unless Enum.any?(quotable(), &String.starts_with?(full, Path.expand(&1, @root) <> "/")) do
      raise ArgumentError,
            "a guide quotes #{path}, which the library neither compiles nor tests. Quote " <>
              "from #{Enum.join(quotable(), ", ")}, so what's quoted is checked"
    end

    lines = full |> File.read!() |> String.split("\n")

    lines =
      if region do
        region(lines, path, region)
      else
        Enum.reject(lines, &region_line?/1)
      end

    lines |> Enum.join("\n") |> String.trim_trailing()
  end

  defp region_line?(line), do: Regex.match?(@region, String.trim(line))

  defp region_name(line) do
    case Regex.run(@region, String.trim(line)) do
      nil -> nil
      captures -> captures |> tl() |> Enum.find(&(&1 != ""))
    end
  end

  defp region(lines, path, name) do
    case Enum.drop_while(lines, &(region_name(&1) != name)) do
      [] ->
        raise ArgumentError,
              "a guide quotes #{path}##{name}, but #{path} has no `guide:#{name}` line. " <>
                "Mark the region with `# guide:#{name}` and `# guide:end`, or in CSS " <>
                "`/* guide:#{name} */` and `/* guide:end */`, or in a template " <>
                "`<%!-- guide:#{name} --%>` and `<%!-- guide:end --%>`."

      [_start | rest] ->
        rest |> Enum.take_while(&(region_name(&1) != "end")) |> dedent()
    end
  end

  defp dedent(lines) do
    indent =
      lines
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(&(String.length(&1) - String.length(String.trim_leading(&1))))
      |> Enum.min(fn -> 0 end)

    Enum.map(lines, &String.slice(&1, indent..-1//1))
  end

  @doc """
  The part of a guide's `text` that a heading naming `name` in backticks
  starts, to the next heading of the same level or higher, or nil when no
  heading names it. A line in a fenced block is never a heading, so an
  Elixir comment there doesn't end the section.
  """
  def section(text, name) do
    {lines, _fence} =
      text
      |> String.split("\n")
      |> Enum.map_reduce(nil, fn line, fence ->
        cond do
          fence && closing_fence?(line, fence) -> {{line, nil}, nil}
          fence -> {{line, nil}, fence}
          opened = opening_fence(line) -> {{line, nil}, elem(opened, 1)}
          true -> {{line, heading_level(line)}, nil}
        end
      end)

    case Enum.drop_while(lines, fn {line, level} -> !(level && line =~ "`#{name}`") end) do
      [] ->
        nil

      [{_heading, level} = start | rest] ->
        body = Enum.take_while(rest, fn {_line, other} -> is_nil(other) or other > level end)
        Enum.map_join([start | body], "\n", &elem(&1, 0))
    end
  end

  defp heading_level(line) do
    case Regex.run(~r/^(\#{1,6})\s/, line) do
      [_, hashes] -> byte_size(hashes)
      nil -> nil
    end
  end

  @doc "The `mix` tasks a guide's `run` blocks may name that aren't billboard's."
  def outside_tasks,
    do: ~w(phx.new phx.gen.auth deps.get compile igniter.install ash.codegen ecto.create
         ecto.migrate test format assets.build phx.server)
end
