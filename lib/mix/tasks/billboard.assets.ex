defmodule Mix.Tasks.Billboard.Assets do
  @shortdoc "Links billboard's CSS and JavaScript into assets/vendor/billboard"
  @moduledoc """
  Links billboard into the site's assets, at `assets/vendor/billboard`,
  so `app.css` and `app.js` import billboard by one path, whether it's a
  git dependency (`deps/billboard`) or a local checkout (`path:`):

      @import "../vendor/billboard/assets/css/theme.css";
      @import "../vendor/billboard/assets/css/editor.css";
      @source "../vendor/billboard/lib/billboard/sections";
      @source "../vendor/billboard/lib/billboard/sections.ex";
      @source "../vendor/billboard/lib/billboard/editor_live.ex";
      @source "../vendor/billboard/lib/billboard/editor_live";
      @source "../vendor/billboard/lib/billboard/editor";

      import {EditCanvas, InlineWords} from "../vendor/billboard/assets/js/billboard.js"

  Tailwind reads only the files where billboard draws classes, its
  sections, the page, and the editor, so the words in the rest of its
  code build no utilities.

  It points the link at billboard as Mix found it, every run, so run it
  before Tailwind and esbuild, in the site's `assets.build` and
  `assets.deploy` aliases. The link is relative, so it holds wherever
  the site's checkout sits, as in a container that copies it. Keep
  `assets/vendor/billboard` out of git. `--to PATH` links somewhere else.
  """
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: [to: :string])
    to = Keyword.get(opts, :to, "assets/vendor/billboard")
    from = Path.relative_to(source(), Path.expand(Path.dirname(to)), force: true)

    File.mkdir_p!(Path.dirname(to))

    case File.read_link(to) do
      {:ok, ^from} ->
        :ok

      {:ok, _elsewhere} ->
        File.rm!(to)
        File.ln_s!(from, to)

      {:error, :enoent} ->
        File.ln_s!(from, to)

      {:error, _not_a_link} ->
        Mix.raise("#{to} is there, and isn't a link. Move it, and run mix billboard.assets again")
    end

    Mix.shell().info("#{to} -> #{from}")
  end

  # Billboard as the site's dependency, or, in billboard's own project,
  # the project itself.
  defp source do
    case Map.fetch(Mix.Project.deps_paths(), :billboard) do
      {:ok, path} ->
        Path.expand(path)

      :error ->
        if Mix.Project.config()[:app] == :billboard,
          do: File.cwd!(),
          else: Mix.raise("billboard isn't a dependency of this project. Add it to mix.exs")
    end
  end
end
