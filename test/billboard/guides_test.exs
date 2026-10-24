defmodule Billboard.GuidesTest do
  @moduledoc """
  Every code block in the guides is checked: copied from a compiled and
  tested file, run by the integration check, or failing to compile with
  the message the guide shows. `site:` blocks are the integration
  check's, against the site it builds.
  """
  # The failing examples compile modules, and purge them after.
  use ExUnit.Case, async: false

  alias Billboard.Test.Guides

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

    test "names a region or a file that isn't there" do
      assert_raise ArgumentError, ~r/has no `# guide:nope` line/, fn ->
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

  defp assert_from(block) do
    assert block.text == Guides.source(block.arg),
           "#{block.guide}:#{block.line} differs from #{block.arg}. Copy the block from it, " <>
             "or change the file and its tests first"
  end

  defp assert_run(block) do
    for line <- String.split(block.text, "\n"), line != "" do
      assert line =~ ~r/^cd [\w.\/-]+$/ or task_known?(line),
             "#{block.guide}:#{block.line} runs `#{line}`, which the integration check can't. " <>
               "A `run` block holds `cd DIR` and `mix` tasks it knows (Guides.outside_tasks/0)"
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
    {:ok, quoted} = Code.string_to_quoted(block.text)

    for module <- billboard_modules(quoted) do
      assert Code.ensure_loaded?(module),
             "#{block.guide}:#{block.line} names #{inspect(module)}, which doesn't exist"
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

  defp task_known?("mix " <> rest) do
    task = rest |> String.split(" ", parts: 2) |> hd()
    task in Guides.outside_tasks() or Mix.Task.get(task) != nil
  end

  defp task_known?(_line), do: false

  defp squash(text), do: text |> String.split() |> Enum.join(" ")

  defp billboard_modules(quoted) do
    {_, modules} =
      Macro.prewalk(quoted, [], fn
        {:__aliases__, _, [:Billboard | _] = parts} = node, acc ->
          {node, [Module.concat(parts) | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.uniq(modules)
  end

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
