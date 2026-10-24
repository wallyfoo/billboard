defmodule Billboard.Integration.GuidesTest do
  @moduledoc """
  Builds a site from nothing, as the getting started and component
  guides do, and proves it works. Run it on its own, before each tag:

      mix test --only integration

  It needs the network (Hex, and GitHub for heroicons), PostgreSQL on
  localhost as postgres/postgres, the `phx_new` and `igniter_new`
  archives, and ten minutes or so. It builds against this checkout, makes
  the databases `billboard_check_dev` and `billboard_check_test`, and
  drops them when it ends. When a step fails, it leaves the site where it
  says, to look at.
  """
  use ExUnit.Case, async: false

  import Billboard.Test.Guides, only: [blocks: 1]

  @moduletag :integration
  @moduletag timeout: :infinity

  @root Path.expand("../..", __DIR__)

  setup do
    dir = Path.join(System.tmp_dir!(), "billboard-check-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    %{dir: dir, site: Path.join(dir, "my_site")}
  end

  test "a site built from the guides edits, publishes, and draws its pages", %{
    dir: dir,
    site: site
  } do
    try do
      getting_started = blocks("guides/getting-started.md")
      component = blocks("guides/writing-a-component.md")

      Enum.reduce(getting_started, dir, &step/2)

      File.cp!(
        fixture("billboard_proof_test.exs.txt"),
        Path.join(site, "test/my_site_web/billboard_proof_test.exs")
      )

      sh!("mix test", site)
      check_site_blocks(getting_started, site)

      Enum.reduce(component, site, &step/2)
      check_site_blocks(component, site)

      # The guide's finished FAQ, and the other guides' examples, over
      # what the generator wrote.
      File.cp_r!(Path.join(@root, "guides/examples/lib"), Path.join(site, "lib"))
      sh!("mix format", site)
      sh!("mix compile --warnings-as-errors", site)
      sh!("mix test", site)

      sign_tailwind(site)
      sh!("mix assets.build", site)
      assert File.read!(Path.join(site, "priv/static/assets/css/app.css")) =~ "bb-surface-band"
      assert File.read!(Path.join(site, "priv/static/assets/js/app.js")) =~ "EditCanvas"
    after
      if File.dir?(site) do
        sh("MIX_ENV=test mix ecto.drop --force", site)
        sh("mix ecto.drop --force", site)
      end
    end

    # Only once every step has passed: a failure leaves the site to look at.
    File.rm_rf!(dir)
  end

  # A guide's block, in order. `run` blocks are commands. The getting
  # started guide's dependencies block is the one edit a reader makes by
  # hand, before billboard is installed, so it's written in, with this
  # checkout in place of the tag; every other `site:` block is checked
  # once its guide has run.
  defp step(%{marker: :run, text: text}, cwd),
    do: text |> String.split("\n", trim: true) |> Enum.reduce(cwd, &command/2)

  defp step(%{marker: :site, arg: "mix.exs", text: "      {:billboard, " <> _ = text}, cwd) do
    path = Path.join(cwd, "mix.exs")
    mix = File.read!(path)
    deps = String.replace(text, ~r/\{:billboard, [^}]*\}/, ~s|{:billboard, path: "#{@root}"}|)

    unless String.contains?(mix, deps) do
      File.write!(
        path,
        String.replace(mix, "  defp deps do\n    [\n", "  defp deps do\n    [\n" <> deps <> "\n",
          global: false
        )
      )
    end

    cwd
  end

  defp step(_block, cwd), do: cwd

  defp command("cd " <> path, cwd), do: Path.expand(path, cwd)

  defp command(line, cwd) do
    sh!(line, cwd)
    if String.starts_with?(line, "mix phx.new "), do: rename_databases(Path.join(cwd, "my_site"))
    cwd
  end

  # Databases of the check's own, so it never touches a my_site_dev
  # someone has.
  defp rename_databases(site) do
    for {file, from, to} <- [
          {"config/dev.exs", "my_site_dev", "billboard_check_dev"},
          {"config/test.exs", "my_site_test", "billboard_check_test"}
        ] do
      path = Path.join(site, file)
      File.write!(path, String.replace(File.read!(path), ~s|"#{from}|, ~s|"#{to}|))
    end
  end

  # The dependencies block is checked as it was written in, with this
  # checkout's path.
  defp check_site_blocks(blocks, site) do
    for %{marker: :site, arg: path} = block <- blocks,
        not String.starts_with?(block.text, "      {:billboard, ") do
      file = Path.join(site, path)

      assert File.exists?(file),
             "#{block.guide}:#{block.line} shows #{path}, which the site hasn't got"

      assert holds_lines?(File.read!(file), block.text),
             "#{block.guide}:#{block.line}: #{path} doesn't hold the guide's block. It holds:\n\n#{File.read!(file)}"
    end
  end

  # The block's lines, in order and together, trailing spaces aside.
  defp holds_lines?(content, text) do
    lines =
      text
      |> String.trim_trailing("\n")
      |> String.split("\n")
      |> Enum.map(&String.trim_trailing/1)

    content
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.chunk_every(length(lines), 1, :discard)
    |> Enum.member?(lines)
  end

  # Tailwind's macOS download can arrive with a signature macOS refuses,
  # and is killed (137) when run; the getting started guide says to sign
  # it again, and so does the check.
  defp sign_tailwind(site) do
    if match?({:unix, :darwin}, :os.type()) do
      sh!("mix tailwind.install", site)
      sh!("codesign --force --sign - _build/tailwind-*", site)
    end
  end

  defp fixture(name), do: Path.join([@root, "test/integration/fixtures", name])

  defp sh!(line, cwd) do
    case sh(line, cwd) do
      {out, 0} ->
        out

      {out, status} ->
        flunk("""
        `#{line}` in #{cwd} exited #{status}#{if status == 137, do: " (killed by the system: on macOS, a downloaded binary whose signature doesn't check out)", else: ""}:

        #{out |> String.split("\n") |> Enum.take(-60) |> Enum.join("\n")}

        The site is left in #{cwd}.
        """)
    end
  end

  # Each command runs in a fresh shell, with none of this test run's Mix
  # environment.
  defp sh(line, cwd) do
    env = [
      {"MIX_ENV", nil},
      {"MIX_TEST_PARTITION", nil},
      {"MIX_BUILD_PATH", nil},
      {"MIX_DEPS_PATH", nil},
      {"MIX_EXS", nil}
    ]

    System.cmd("sh", ["-c", line], cd: cwd, env: env, stderr_to_stdout: true)
  end
end
