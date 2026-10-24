defmodule Billboard.Test.Guides do
  @moduledoc """
  Reads the guides' code blocks and their markers, and the regions of
  library files they quote, for `guides_test.exs` and the integration
  check.

  A block's marker is the HTML comment on the line before its opening
  fence, blank lines between allowed: `<!-- from: PATH -->`,
  `<!-- from: PATH#NAME -->`, `<!-- site: PATH -->`, `<!-- run -->`,
  `<!-- fails -->`, or `<!-- sketch -->`. ExDoc doesn't draw it.

  The guides fence code with three backticks, and nothing else: a block
  fenced with tildes or more backticks, or indented four spaces outside
  a list, is read too, with its `fence`, so the check can refuse it
  rather than miss code ExDoc draws.

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

  # A list item's first line, which keeps a list going.
  @list_item ~r/^ {0,3}(?:[-*+]|\d+[.)])\s/

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
    |> Enum.with_index(1)
    |> collect(%{guide: guide, marker: nil, blank?: true, list?: false}, [])
  end

  # Outside a block: a marker is held until the next fence, across blank
  # lines, and any other line drops it. Whether the line before was
  # blank, and whether a list is open, say if an indented line is code.
  defp collect([], _state, acc), do: Enum.reverse(acc)

  defp collect([{line, n} | rest] = lines, state, acc) do
    trimmed = String.trim(line)

    cond do
      match = Regex.run(@marker, trimmed) ->
        [_, kind | arg] = match
        arg = if arg in [[], [""]], do: nil, else: hd(arg)
        # One of the five kinds the regex names, so the atom is safe.
        state = %{state | marker: {String.to_atom(kind), arg}, blank?: false, list?: false}
        collect(rest, state, acc)

      fence = opening_fence(line) ->
        lang = trimmed |> String.trim_leading(String.first(fence)) |> String.trim()
        {body, rest} = fenced(rest, fence)
        acc = [block(state, n, lang, body, fence) | acc]
        collect(rest, %{state | marker: nil, blank?: false}, acc)

      trimmed == "" ->
        collect(rest, %{state | blank?: true}, acc)

      state.blank? and not state.list? and String.starts_with?(line, "    ") ->
        {body, rest} = indented(lines)
        acc = [block(state, n, "", body, :indented) | acc]
        collect(rest, %{state | marker: nil, blank?: false}, acc)

      true ->
        list? = Regex.match?(@list_item, line) or (state.list? and line =~ ~r/^\s/)
        collect(rest, %{state | marker: nil, blank?: false, list?: list?}, acc)
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

  # The fence a line opens: three or more backticks, or tildes. An
  # opening fence may be indented.
  defp opening_fence(line) do
    case Regex.run(~r/^\s*(`{3,}|~{3,})/, line) do
      [_, fence] -> fence
      nil -> nil
    end
  end

  # A fenced block's lines, until the fence that closes it: the same
  # character, at least as many times, alone on its line.
  defp fenced(lines, fence) do
    char = String.first(fence)

    {body, rest} =
      Enum.split_while(lines, fn {line, _n} ->
        not (String.trim(line)
             |> String.match?(~r/^#{Regex.escape(char)}{#{byte_size(fence)},}$/))
      end)

    {Enum.map(body, &elem(&1, 0)), Enum.drop(rest, 1)}
  end

  # An indented block's lines: while each is blank or four spaces in,
  # less the blank lines it ends with.
  defp indented(lines) do
    {body, rest} =
      Enum.split_while(lines, fn {line, _n} ->
        String.trim(line) == "" or String.starts_with?(line, "    ")
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

    unless Enum.any?(quotable(), &String.starts_with?(path, &1 <> "/")) do
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

  @doc "The `mix` tasks a guide's `run` blocks may name that aren't billboard's."
  def outside_tasks,
    do: ~w(phx.new phx.gen.auth deps.get compile igniter.install ash.codegen ecto.create
         ecto.migrate test format assets.build phx.server)
end
