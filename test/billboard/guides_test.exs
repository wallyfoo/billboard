defmodule Billboard.GuidesTest do
  @moduledoc """
  Every code block in the guides is checked: copied from a compiled and
  tested file, run by the integration check, or failing to compile with
  the message the guide shows. `site:` blocks are the integration
  check's, against the site it builds.
  """
  # The failing examples compile modules, and purge them after.
  use ExUnit.Case, async: false

  alias Billboard.Test.{Guides, Theme}

  @version Mix.Project.config()[:version]

  for guide <- Guides.guides() do
    describe guide do
      test "marks every code block with how it's checked" do
        unmarked = unmarked(Guides.blocks(unquote(guide)))

        assert unmarked == [],
               "these blocks say nothing of how they're checked: #{Enum.join(unmarked, ", ")}. " <>
                 "Put `<!-- from: PATH#REGION -->`, `<!-- site: PATH -->`, `<!-- run -->`, " <>
                 "`<!-- fails -->`, or `<!-- sketch -->` on the line before each"
      end

      test "fences its code with three backticks, and nothing else" do
        assert_fences(Guides.blocks(unquote(guide)))
      end

      test "gives `from:` and `site:` a path, and the other markers none" do
        assert_marker_args(Guides.blocks(unquote(guide)))
      end

      test "copies its `from:` blocks from the library, word for word" do
        for %{marker: :from} = block <- Guides.blocks(unquote(guide)), do: assert_from(block)
      end

      test "runs only commands the integration check knows" do
        for %{marker: :run} = block <- Guides.blocks(unquote(guide)), do: assert_run(block)
      end

      test "shows the messages its failing examples give" do
        blocks = Guides.blocks(unquote(guide))

        for {%{marker: :fails} = block, i} <- Enum.with_index(blocks),
            do: assert_fails(block, Enum.at(blocks, i + 1))
      end

      test "names only modules that exist in its sketches" do
        for %{marker: :sketch} = block <- Guides.blocks(unquote(guide)), do: assert_sketch(block)
      end

      test "links to the library's source at this version, at paths that exist" do
        assert_links(unquote(guide), File.read!(unquote(guide)))
      end
    end
  end

  test "uses four sketches at most, in all the guides" do
    sketches = for guide <- Guides.guides(), %{marker: :sketch} <- Guides.blocks(guide), do: guide
    assert length(sketches) <= 4
  end

  describe "the parts guide" do
    # Each stock part's section has a table of its fields, whose first
    # column is each field in backticks, and a table of what the editor
    # shows, whose first column is plain words, so the scan sees only the
    # fields.
    test "lists each stock part's fields, and only those" do
      text = File.read!("guides/parts.md")

      # Six modules: `:link`, among `Parts.parts/0`, is an action.
      alias Billboard.Parts.{Action, Detail, Head, Photo, Point, Quote}

      for module <- [Head, Action, Photo, Point, Detail, Quote] do
        section = Guides.section(text, inspect(module))

        assert section,
               "guides/parts.md has no section naming #{inspect(module)}. Give it a heading " <>
                 "that names `#{inspect(module)}`"

        fields =
          for %{name: name, public?: true} <- Ash.Resource.Info.attributes(module),
              name != :id,
              do: to_string(name)

        for field <- fields do
          assert section =~ "| `#{field}` |",
                 "guides/parts.md leaves out #{inspect(module)}'s `#{field}`. Add a row for it " <>
                   "to the fields table"
        end

        named = for [_, field] <- Regex.scan(~r/^\| `([a-z_]+)` \|/m, section), do: field

        assert Enum.sort(named) == Enum.sort(fields),
               "guides/parts.md names fields #{inspect(module)} hasn't got, or names one twice: " <>
                 "#{inspect(named -- fields)}"
      end
    end
  end

  describe "the theming guide" do
    # Every token a site sets for billboard: those the theme, the
    # sections, and the buttons read, and the nine noise tokens, which the
    # placeholder reads through inline styles that name them by number.
    test "names every token the theme reads, and no token it doesn't" do
      text = File.read!("guides/theming.md")
      noise = for n <- 1..9, do: "--bb-noise-#{n}"

      for token <- Theme.site_tokens() ++ noise do
        assert text =~ ~r/`#{Regex.escape(token)}(?![a-z0-9-])/,
               "guides/theming.md leaves out #{token}. Name it, in backticks, with what it's " <>
                 "for and its fallback"
      end

      # What billboard reads or sets: the site's tokens, and the editor's
      # own, which editor.css sets on :root. A family, such as
      # `--bb-edit-*`, must name the start of some token.
      known = Theme.read_or_set_tokens(Theme.site_reads()) ++ noise
      named = for [_, t] <- Regex.scan(~r/`(--bb-[a-z0-9-]*[a-z0-9])(?![a-z0-9-])/, text), do: t
      stray = Enum.uniq(named) -- known

      assert stray == [],
             "guides/theming.md names tokens billboard doesn't read: #{Enum.join(stray, ", ")}"

      for [_, family] <- Regex.scan(~r/`(--bb-[a-z0-9-]+-)\*`/, text) do
        assert Enum.any?(known, &String.starts_with?(&1, family)),
               "guides/theming.md names the family #{family}*, which no token is in"
      end
    end

    test "names every hook class" do
      text = File.read!("guides/theming.md")

      for hook <- ~w(bb-title bb-eyebrow bb-heading bb-section-head bb-point bb-detail
                     bb-item-title bb-quote bb-photo bb-button bb-link) do
        assert text =~ "| `#{hook}` |", "guides/theming.md's table of hooks leaves out #{hook}"
      end
    end
  end

  # The checks, on guides written here, so each is seen to pass what's
  # right and fail what isn't before any guide leans on it.
  describe "the check itself" do
    test "finds a block with no marker, but not a text block" do
      guide = """
      # A guide

      <!-- run -->

      ```bash
      mix deps.get
      ```

      ```text
      Some output.
      ```

      <!-- run -->
      Prose between drops the marker.

      ```elixir
      IO.puts("unmarked")
      ```
      """

      blocks = Guides.parse(guide, "guides/a.md")

      assert [%{marker: :run, lang: "bash", text: "mix deps.get", line: 5}, %{lang: "text"}, _] =
               blocks

      assert unmarked(blocks) == ["guides/a.md:16"]
    end

    test "quotes a region, dedented, and a whole file without its region lines" do
      region = Guides.source("guides/examples/lib/my_site/sections/faq.ex#component")

      assert region =~ ~r/\Acomponent do\n  key :faq\n/
      assert String.ends_with?(region, "\nend")
      refute region =~ "# guide:"

      whole = Guides.source("guides/examples/lib/my_site/sections/faq.ex")
      assert whole =~ ~r/\Adefmodule MySite.Sections.Faq do\n/
      refute whole =~ "# guide:"

      assert_from(%Guides.Block{
        guide: "guides/a.md",
        line: 1,
        marker: :from,
        arg: "guides/examples/lib/my_site/sections/faq.ex#component",
        text: region
      })

      assert_raise ExUnit.AssertionError, ~r/differs from/, fn ->
        assert_from(%Guides.Block{
          guide: "guides/a.md",
          line: 1,
          marker: :from,
          arg: "guides/examples/lib/my_site/sections/faq.ex#component",
          text: "component do\nend"
        })
      end
    end

    test "refuses code fenced any other way, or indented outside a list" do
      guide = """
      # A guide

      ~~~elixir
      IO.puts("tildes")
      ~~~

      ````elixir
      IO.puts("four")
      ````

      A paragraph.

          IO.puts("indented")

      - A list item

          still the item's, not code

      <!-- sketch -->
      ```elixir
      IO.puts("fine")
      ```
      """

      blocks = Guides.parse(guide, "guides/a.md")

      assert [
               %{fence: "~~~", text: ~s|IO.puts("tildes")|, line: 3},
               %{fence: "````", text: ~s|IO.puts("four")|},
               %{fence: :indented, text: ~s|    IO.puts("indented")|, line: 13},
               %{fence: "```", marker: :sketch}
             ] = blocks

      error = assert_raise ExUnit.AssertionError, fn -> assert_fences(blocks) end
      assert error.message =~ "guides/a.md:3, guides/a.md:7, guides/a.md:13"
      assert error.message =~ "three backticks"
    end

    # Each of these is code ExDoc draws, so each is a block the check
    # sees, and refuses: none is three backticks at the margin or in a
    # list item's words.
    test "sees code in a blockquote, on a list item's line, in a list, after a heading, or raw" do
      guide = """
      # A guide

      > ```elixir
      > IO.puts("quoted")
      > ```

      - ```elixir
        IO.puts("on the item")
        ```

      - An item, whose words are its own

              IO.puts("deep in the item")

      ## A heading
          IO.puts("after a heading")

      <!-- a comment -->
          IO.puts("after a comment")

      ```elixir
      IO.puts("fenced")
      ```
          IO.puts("after a fence")

      A paragraph.
      \tIO.puts("tabbed, but the paragraph's")

      \tIO.puts("tabbed")

      <pre><code>IO.puts("raw")</code></pre>
      """

      blocks = Guides.parse(guide, "guides/a.md")

      assert [
               %{fence: "> ```", text: ~s|> IO.puts("quoted")|, line: 3},
               %{fence: "- ```", text: ~s|  IO.puts("on the item")|, line: 7},
               %{fence: :indented, text: ~s|        IO.puts("deep in the item")|, line: 13},
               %{fence: :indented, text: ~s|    IO.puts("after a heading")|, line: 16},
               %{fence: :indented, text: ~s|    IO.puts("after a comment")|, line: 19},
               %{fence: "```", text: ~s|IO.puts("fenced")|},
               %{fence: :indented, text: ~s|    IO.puts("after a fence")|, line: 24},
               %{fence: :indented, text: ~s|    IO.puts("tabbed")|, line: 29},
               %{fence: :pre, line: 31}
             ] = blocks

      error = assert_raise ExUnit.AssertionError, fn -> assert_fences(blocks) end

      for line <- [3, 7, 13, 16, 19, 24, 29, 31],
          do: assert(error.message =~ "guides/a.md:#{line}")

      refute error.message =~ "guides/a.md:21"
    end

    test "refuses a `from:` or `site:` with no path, and a path on another marker" do
      guide = """
      <!-- site -->
      ```elixir
      x
      ```

      <!-- from: -->
      ```elixir
      x
      ```

      <!-- run: mix.exs -->
      ```bash
      mix test
      ```

      <!-- site: mix.exs -->
      ```elixir
      x
      ```
      """

      error =
        assert_raise ExUnit.AssertionError, fn ->
          assert_marker_args(Guides.parse(guide, "guides/a.md"))
        end

      assert error.message =~ "guides/a.md:2, guides/a.md:7, guides/a.md:12"
      refute error.message =~ "guides/a.md:17"
    end

    test "quotes a region of a CSS file or a template, and a whole one without its region lines" do
      assert Guides.source("test/support/guides/regions.css#paper") ==
               ":root {\n  --bb-ink: #1c1c1c;\n}"

      refute Guides.source("test/support/guides/regions.css") =~ "guide:"
      assert Guides.source("test/support/guides/regions.css") =~ "--bb-ink"

      assert Guides.source("test/support/guides/regions.html.heex#title") ==
               "<h2>{@title}</h2>"

      refute Guides.source("test/support/guides/regions.html.heex") =~ "guide:"
    end

    test "quotes only what the library compiles or tests" do
      assert_raise ArgumentError,
                   ~r/README.md, which the library neither compiles nor tests/,
                   fn ->
                     Guides.source("README.md")
                   end

      assert_raise ArgumentError, ~r/which the library neither compiles nor tests/, fn ->
        Guides.source("lib/../README.md")
      end

      assert Guides.source("priv/templates/billboard.install/page.ex.eex") =~ "use Billboard.Page"
      assert Guides.source("assets/css/theme.css") =~ "bb-"
    end

    test "names a region or a file that isn't there" do
      assert_raise ArgumentError, ~r/has no `guide:nope` line/, fn ->
        Guides.source("guides/examples/lib/my_site/sections/faq.ex#nope")
      end

      assert_raise ArgumentError, ~r/isn't in the library/, fn ->
        Guides.source("lib/nope.ex")
      end
    end

    test "knows the commands the integration check runs" do
      assert_run(block(:run, "cd my_site\nmix billboard.install --home\nmix ecto.migrate"))

      assert_raise ExUnit.AssertionError, ~r/runs `rm -rf _build`/, fn ->
        assert_run(block(:run, "rm -rf _build"))
      end

      assert_raise ExUnit.AssertionError, ~r/runs `mix billboard.nope`/, fn ->
        assert_run(block(:run, "mix billboard.nope"))
      end

      # The integration check runs each line as a list of arguments, not
      # through a shell, so a shell's operators would reach mix as words.
      for line <- [
            "mix deps.get && mix compile",
            "mix compile; mix test",
            "mix test | tee x",
            "mix test > out",
            "mix test `echo x`"
          ] do
        assert_raise ExUnit.AssertionError, ~r/no shell/, fn -> assert_run(block(:run, line)) end
      end
    end

    test "sees a failing example's verifier error, and the message it gives" do
      failing =
        block(:fails, """
        defmodule MySite.Sections.Typo do
          use Billboard.Component

          component do
            key :typo
            label "Typo"
            hint "A typo."
            category :content
          end

          editor do
            words :titel, label: "Title"
          end

          attributes do
            attribute :title, :string, public?: true
          end
        end
        """)

      assert_fails(failing, %Guides.Block{
        lang: "text",
        text: "`:titel` is in `editor` but isn't an attribute of\n MySite.Sections.Typo"
      })

      assert_raise ExUnit.AssertionError, ~r/fails with/, fn ->
        assert_fails(failing, %Guides.Block{lang: "text", text: "something else"})
      end

      assert_raise ExUnit.AssertionError, ~r/needs a `text` block after it/, fn ->
        assert_fails(failing, nil)
      end
    end

    test "names a sketch's billboard module that doesn't exist" do
      assert_sketch(block(:sketch, "Billboard.Sections.Words.text(ctx, \"title\", title)"))

      assert_raise ExUnit.AssertionError, ~r/names Billboard.Nope/, fn ->
        assert_sketch(block(:sketch, "Billboard.Nope.call()"))
      end
    end

    test "names a sketch's billboard function that doesn't exist, piped or not" do
      assert_sketch(block(:sketch, "ctx |> Billboard.Sections.Words.text(\"title\", title)"))

      assert_raise ExUnit.AssertionError, ~r/calls Billboard.Sections.Words.nope\/1/, fn ->
        assert_sketch(block(:sketch, "Billboard.Sections.Words.nope(ctx)"))
      end

      assert_raise ExUnit.AssertionError, ~r/calls Billboard.Sections.Words.text\/1/, fn ->
        assert_sketch(block(:sketch, "Billboard.Sections.Words.text(ctx)"))
      end
    end

    test "follows a sketch's aliases and imports to the billboard functions they name" do
      assert_sketch(
        block(:sketch, """
        alias Billboard.Sections.{Parts, Words}
        alias Billboard.Sections.EditorFields, as: Fields
        import Billboard.Rule, only: [warning: 2]
        Parts.blank(:point)
        Fields.narrowed(:faq)
        Words.editing?(%{})
        """)
      )

      assert_raise ExUnit.AssertionError, ~r/Billboard.Sections.Parts.nope\/1/, fn ->
        assert_sketch(block(:sketch, "alias Billboard.Sections.Parts\nParts.nope(1)"))
      end

      assert_raise ExUnit.AssertionError, ~r/Billboard.Sections.Nope, which doesn't exist/, fn ->
        assert_sketch(block(:sketch, "alias Billboard.Sections\nSections.Nope.go()"))
      end

      assert_raise ExUnit.AssertionError, ~r/Billboard.Rule.nope\/2/, fn ->
        assert_sketch(block(:sketch, "import Billboard.Rule, only: [nope: 2]"))
      end
    end

    test "says a sketch that doesn't parse doesn't" do
      assert_raise ExUnit.AssertionError, ~r/guides\/a.md:1 is a sketch that isn't Elixir/, fn ->
        assert_sketch(block(:sketch, "precommit: [1]"))
      end
    end

    test "reads the section a heading names, to the next heading as high" do
      guide = """
      # A guide

      ## Head (`Billboard.Parts.Head`)

      | `heading` | text |

      ```elixir
      # Not a heading.
      ```

      ### Within it

      ## Action (`Billboard.Parts.Action`)

      The next one.
      """

      section = Guides.section(guide, "Billboard.Parts.Head")

      assert section =~ ~r/\A## Head/
      assert section =~ "# Not a heading."
      assert section =~ "### Within it"
      refute section =~ "Action"
      assert Guides.section(guide, "Billboard.Parts.Action") =~ "The next one."
      assert Guides.section(guide, "Billboard.Parts.Quote") == nil
    end

    test "names a link to the source at another version, or at a path that isn't there" do
      at = "https://github.com/wallyfoo/billboard/blob"

      assert_links(
        "guides/a.md",
        "[Details](#{at}/v#{@version}/lib/billboard/sections/details.ex)"
      )

      assert_raise ExUnit.AssertionError, ~r/v0\.0\.1/, fn ->
        assert_links("guides/a.md", "[Details](#{at}/v0.0.1/lib/billboard/sections/details.ex)")
      end

      assert_raise ExUnit.AssertionError, ~r/lib\/nope.ex, which isn't there/, fn ->
        assert_links("guides/a.md", "[Nope](#{at}/v#{@version}/lib/nope.ex)")
      end
    end
  end

  defp block(marker, text),
    do: %Guides.Block{guide: "guides/a.md", line: 1, lang: "elixir", marker: marker, text: text}

  defp unmarked(blocks) do
    # A `text` block is output, or a failing example's message: neither
    # needs a marker.
    for block <- blocks, block.marker == nil and block.lang != "text" do
      "#{block.guide}:#{block.line}"
    end
  end

  defp assert_fences(blocks) do
    others = for block <- blocks, block.fence != "```", do: "#{block.guide}:#{block.line}"

    assert others == [],
           "these blocks are drawn as code but not fenced with three backticks: " <>
             "#{Enum.join(others, ", ")}. Fence each with ``` and give it a marker, or, for " <>
             "an indented line that isn't code, take it out to the margin"
  end

  defp assert_marker_args(blocks) do
    wrong =
      for %{marker: marker, arg: arg} = block <- blocks,
          marker != nil,
          (marker in [:from, :site] and is_nil(arg)) or
            (marker not in [:from, :site] and not is_nil(arg)),
          do: "#{block.guide}:#{block.line}"

    assert wrong == [],
           "these blocks' markers are wrong: #{Enum.join(wrong, ", ")}. `from:` and `site:` " <>
             "name a path (`<!-- site: lib/my_site/billboard.ex -->`), and `run`, `fails`, " <>
             "and `sketch` take none"
  end

  defp assert_from(block) do
    assert block.text == Guides.source(block.arg),
           "#{block.guide}:#{block.line} differs from #{block.arg}. Copy the block from it, " <>
             "or change the file and its tests first"
  end

  defp assert_run(block) do
    for line <- String.split(block.text, "\n"), line != "" do
      assert line =~ ~r/^(cd|rm) [\w.\/-]+$/ or task_known?(line),
             "#{block.guide}:#{block.line} runs `#{line}`, which the integration check can't. " <>
               "A `run` block holds `cd DIR`, `rm FILE`, and `mix` tasks it knows (Guides.outside_tasks/0), " <>
               "one to a line, with no shell operators (`&&`, `;`, `|`, `>`, or backticks), " <>
               "since each line runs as a list of arguments, not through a shell"
    end
  end

  defp assert_fails(block, next) do
    assert match?(%{lang: "text"}, next),
           "#{block.guide}:#{block.line} is a failing example, and needs a `text` block after " <>
             "it holding the message it fails with"

    expected = squash(next.text)

    try do
      # Spark's `dsl_errors/1` sees no error here: `Code.compile_string/1`
      # (and `Code.eval_string/1`) run the verifiers in Elixir's parallel
      # checker, another process, where its collector isn't set, so the
      # errors come out as warnings on stderr, which are read instead.
      warnings =
        ExUnit.CaptureIO.capture_io(:stderr, fn -> Code.compile_string(block.text) end)

      assert warnings =~ "Spark.Error.DslError" and String.contains?(squash(warnings), expected),
             "#{block.guide}:#{block.line} fails with #{inspect(String.slice(warnings, 0, 600))}, " <>
               "not #{inspect(expected)}"
    after
      purge(block.text)
    end
  end

  defp assert_sketch(block) do
    quoted =
      case Code.string_to_quoted(block.text) do
        {:ok, quoted} ->
          quoted

        {:error, error} ->
          flunk(
            "#{block.guide}:#{block.line} is a sketch that isn't Elixir (#{inspect(error)}). " <>
              "A sketch must parse, so its modules and functions can be checked: wrap a " <>
              "fragment in what holds it, as `defp aliases do [precommit: …] end`"
          )
      end

    for module <- billboard_modules(quoted) do
      assert Code.ensure_loaded?(module),
             "#{block.guide}:#{block.line} names #{inspect(module)}, which doesn't exist"
    end

    for {module, fun, arity} <- billboard_calls(quoted) do
      assert function_exported?(module, fun, arity) or macro_exported?(module, fun, arity),
             "#{block.guide}:#{block.line} calls #{inspect(module)}.#{fun}/#{arity}, which " <>
               "doesn't exist"
    end
  end

  defp assert_links(guide, text) do
    for [_, tag, path] <-
          Regex.scan(~r{github\.com/wallyfoo/billboard/blob/([^/]+)/([^)\s#]+)}, text) do
      assert tag == "v#{@version}",
             "#{guide} links to the source at #{tag}. Link at v#{@version}, this version"

      assert File.exists?(path), "#{guide} links to #{path}, which isn't there"
    end
  end

  # A shell's operators are refused: the integration check runs each line
  # as a list of arguments, not through a shell.
  defp task_known?("mix " <> rest = line) do
    task = rest |> String.split(" ", parts: 2) |> hd()

    not shell?(line) and (task in Guides.outside_tasks() or Mix.Task.get(task) != nil)
  end

  defp task_known?(_line), do: false

  defp shell?(line), do: line =~ ~r/&&|[;|>`]/

  defp squash(text), do: text |> String.split() |> Enum.join(" ")

  # Each billboard module a sketch names, by its full name or by a short
  # name its `alias` lines give.
  defp billboard_modules(quoted) do
    aliases = billboard_aliases(quoted)

    {_, modules} =
      Macro.prewalk(quoted, [], fn
        {:__aliases__, _, parts} = node, acc when is_list(parts) ->
          case expand(parts, aliases) do
            nil -> {node, acc}
            full -> {node, [Module.concat(full) | acc]}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.uniq(modules)
  end

  # Each call to a billboard module's function, by its full name or an
  # alias, with its arity, one more when it's piped into; and each
  # function an `import Billboard.X, only: [...]` names.
  defp billboard_calls(quoted) do
    aliases = billboard_aliases(quoted)

    {_, calls} =
      Macro.prewalk(quoted, [], fn
        {:|>, _, [left, {{:., _, [{:__aliases__, _, parts}, fun]}, _, args}]} = node, acc
        when is_atom(fun) and is_list(args) ->
          case expand(parts, aliases) do
            nil ->
              {node, acc}

            full ->
              {{:__block__, [], [left | args]},
               [{Module.concat(full), fun, length(args) + 1} | acc]}
          end

        # `alias Billboard.Sections.{Parts, Words}` is a call to `{}`.
        {{:., _, [{:__aliases__, _, parts}, fun]}, _, args} = node, acc
        when is_atom(fun) and fun != :{} and is_list(args) ->
          case expand(parts, aliases) do
            nil -> {node, acc}
            full -> {node, [{Module.concat(full), fun, length(args)} | acc]}
          end

        {:import, _, [{:__aliases__, _, parts}, opts]} = node, acc when is_list(opts) ->
          case expand(parts, aliases) do
            nil ->
              {node, acc}

            full ->
              only =
                for {fun, arity} <- Keyword.get(opts, :only, []),
                    is_integer(arity),
                    do: {Module.concat(full), fun, arity}

              {node, only ++ acc}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.uniq(calls)
  end

  # The short names a sketch's `alias Billboard.…` lines give, to the
  # modules' full names: `Parts` for `alias Billboard.Sections.Parts`, the
  # name `as:` gives, and each name in `alias Billboard.Sections.{Parts, Words}`.
  defp billboard_aliases(quoted) do
    {_, aliases} =
      Macro.prewalk(quoted, %{}, fn
        {:alias, _, [{:__aliases__, _, [:Billboard | _] = parts} | opts]} = node, acc ->
          short =
            case opts do
              [[as: {:__aliases__, _, [as]}]] -> as
              _none -> List.last(parts)
            end

          {node, Map.put(acc, short, parts)}

        {:alias, _, [{{:., _, [{:__aliases__, _, [:Billboard | _] = base}, :{}]}, _, children}]} =
            node,
        acc ->
          acc =
            for {:__aliases__, _, child} <- children, reduce: acc do
              acc -> Map.put(acc, List.last(child), base ++ child)
            end

          {node, acc}

        node, acc ->
          {node, acc}
      end)

    aliases
  end

  defp expand([:Billboard | _] = parts, _aliases), do: parts

  defp expand([first | rest], aliases) when is_atom(first) do
    case aliases do
      %{^first => full} -> full ++ rest
      _other -> nil
    end
  end

  defp expand(_parts, _aliases), do: nil

  defp purge(text) do
    {:ok, quoted} = Code.string_to_quoted(text)

    {_, modules} =
      Macro.prewalk(quoted, [], fn
        {:defmodule, _, [{:__aliases__, _, parts} | _]} = node, acc ->
          {node, [Module.concat(parts) | acc]}

        node, acc ->
          {node, acc}
      end)

    for module <- modules do
      :code.purge(module)
      :code.delete(module)
    end
  end
end
