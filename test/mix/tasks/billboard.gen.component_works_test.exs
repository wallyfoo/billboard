defmodule Mix.Tasks.Billboard.Gen.ComponentWorksTest do
  @moduledoc """
  What mix billboard.gen.component writes passes assert_component_works/2
  as it's written, in both shapes: compiled from the generated files, on a
  site that lists them.
  """
  use Billboard.ComponentCase,
    endpoint: Billboard.Test.Endpoint,
    repo: Billboard.Test.Repo,
    async: false

  import ExUnit.CaptureIO
  import Igniter.Test
  import Billboard.Test.InstallProject

  alias Billboard.Test.Env

  @site Mix.Tasks.Billboard.Gen.ComponentWorksTest.Site

  # The generated components, on a site of their own, with resources as
  # the installer writes them, so the open checks build real sections.
  # Nothing is stored, so its tables are the shop's.
  @site_code """
  defmodule #{inspect(@site)} do
    use Billboard.Site,
      otp_app: :billboard,
      repo: Billboard.Test.Repo,
      pubsub: Billboard.Test.PubSub,
      domain: #{inspect(@site)}.Pages,
      resources: [
        page: #{inspect(@site)}.Page,
        version: #{inspect(@site)}.Version,
        section: #{inspect(@site)}.Section,
        content: #{inspect(@site)}.Content
      ],
      components: [
        Billboard.Components.Hero,
        MySite.Sections.Notes,
        MySite.Sections.Blurb
      ],
      surfaces: [%{name: "plain", label: "Plain"}, %{name: "loud", label: "Loud"}],
      offered: [page: ["plain"], stand_out: ["loud"], card: []],
      layout: Billboard.Test.Layout

    pages do
      page "/", "Home", kind: :free
    end
  end

  defmodule #{inspect(@site)}.Content do
    use Billboard.Content, site: #{inspect(@site)}
  end

  defmodule #{inspect(@site)}.Page do
    use Billboard.Page, site: #{inspect(@site)}
  end

  defmodule #{inspect(@site)}.Version do
    use Billboard.Version, site: #{inspect(@site)}
  end

  defmodule #{inspect(@site)}.Section do
    use Billboard.Section, site: #{inspect(@site)}
  end

  defmodule #{inspect(@site)}.Pages do
    use Billboard.Domain, site: #{inspect(@site)}, validate_config_inclusion?: false
  end
  """

  setup_all do
    installed = project() |> Igniter.compose_task("billboard.install", []) |> apply_igniter!()

    generated =
      [["MySite.Sections.Notes", "--list", "note"], ["MySite.Sections.Blurb"]]
      |> Enum.flat_map(fn argv ->
        igniter = Igniter.compose_task(installed, "billboard.gen.component", argv)
        dir = argv |> hd() |> String.split(".") |> List.last() |> Macro.underscore()

        # The part first, then the renderer, then the component that names both.
        for path <- [
              "lib/my_site/sections/#{dir}/#{Igniter.Inflex.singularize(dir)}.ex",
              "lib/my_site_web/sections/#{dir}.ex",
              "lib/my_site/sections/#{dir}.ex"
            ],
            Rewrite.has_source?(igniter.rewrite, path),
            do: content(igniter, path)
      end)

    warnings =
      capture_io(:stderr, fn ->
        modules =
          for code <- generated ++ [@site_code],
              {module, _} <- Code.compile_string(code),
              do: module

        send(self(), {:modules, modules})
      end)

    assert_received {:modules, modules}

    on_exit(fn ->
      for module <- modules do
        :code.purge(module)
        :code.delete(module)
      end
    end)

    %{warnings: warnings}
  end

  setup do
    Env.put_env_for_test(:billboard, :site, @site)
  end

  test "compiles without a warning", %{warnings: warnings} do
    assert warnings == ""
  end

  test "a component with a list of its own parts works as generated" do
    assert_component_works(MySite.Sections.Notes)
  end

  test "a component of a title and some words works as generated" do
    assert_component_works(MySite.Sections.Blurb)
  end
end
