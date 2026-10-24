defmodule Billboard.Test.Guides do
  @moduledoc """
  Reads the guides' fenced blocks and their markers, and the regions of
  library files they quote, for `guides_test.exs` and the integration
  check.

  A block's marker is the HTML comment on the line before its opening
  fence, blank lines between allowed: `<!-- from: PATH -->`,
  `<!-- from: PATH#NAME -->`, `<!-- site: PATH -->`, `<!-- run -->`,
  `<!-- fails -->`, or `<!-- sketch -->`. ExDoc doesn't draw it. A region
  of a file is the lines between `# guide:NAME` and `# guide:end`.
  """

  alias Billboard.Test.Guides.Block

  @root Path.expand("../..", __DIR__)

  @marker ~r/^<!-- (from|site|run|fails|sketch)(?::\s*(\S+))? -->$/

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
    |> collect(guide, nil, nil, [])
  end

  # Outside a block: a marker is held until the next fence, across blank
  # lines, and any other line drops it.
  defp collect([], _guide, _marker, nil, acc), do: Enum.reverse(acc)

  defp collect([{line, n} | rest], guide, marker, nil, acc) do
    cond do
      match = Regex.run(@marker, String.trim(line)) ->
        [_, kind | arg] = match
        # One of the five kinds the regex names, so the atom is safe.
        collect(rest, guide, {String.to_atom(kind), List.first(arg)}, nil, acc)

      String.starts_with?(String.trim_leading(line), "```") ->
        lang = line |> String.trim() |> String.trim_leading("`") |> String.trim()
        collect(rest, guide, nil, {lang, n, marker, []}, acc)

      String.trim(line) == "" ->
        collect(rest, guide, marker, nil, acc)

      true ->
        collect(rest, guide, nil, nil, acc)
    end
  end

  # Inside a block, until its closing fence.
  defp collect([{line, _n} | rest], guide, _marker, {lang, start, marker, lines}, acc) do
    if String.trim(line) == "```" do
      {kind, arg} = marker || {nil, nil}

      block = %Block{
        guide: guide,
        line: start,
        lang: lang,
        text: lines |> Enum.reverse() |> Enum.join("\n"),
        marker: kind,
        arg: arg
      }

      collect(rest, guide, nil, nil, [block | acc])
    else
      collect(rest, guide, nil, {lang, start, marker, [line | lines]}, acc)
    end
  end

  @doc """
  A library file, its `# guide:` lines dropped, or a region of one
  (`path#name`), dedented, as a guide shows it. Raises, naming the fix,
  when the file or the region isn't there.
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

    lines = full |> File.read!() |> String.split("\n")

    lines =
      if region do
        region(lines, path, region)
      else
        Enum.reject(lines, &String.match?(String.trim(&1), ~r/^# guide:/))
      end

    lines |> Enum.join("\n") |> String.trim_trailing()
  end

  defp region(lines, path, name) do
    case Enum.drop_while(lines, &(String.trim(&1) != "# guide:#{name}")) do
      [] ->
        raise ArgumentError,
              "a guide quotes #{path}##{name}, but #{path} has no `# guide:#{name}` line. " <>
                "Mark the region with `# guide:#{name}` and `# guide:end`."

      [_start | rest] ->
        rest |> Enum.take_while(&(String.trim(&1) != "# guide:end")) |> dedent()
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
