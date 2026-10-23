defmodule Billboard.Starter do
  @moduledoc """
  What a page shows before its first commit: its starter, an unsaved
  version of the site's version resource with `status: :starter` and its
  sections, each with its `children` loaded. A page with no live version
  renders its starter, and its first edit copies it into a draft, so the
  first commit changes nothing a visitor didn't change.

  A site names its starter module in `use Billboard.Site`, as
  `starter: MySite.Pages.Starter`:

      defmodule MySite.Pages.Starter do
        @behaviour Billboard.Starter

        alias MySite.Pages.{Section, Version}

        @impl true
        def version("/") do
          hero = Billboard.Component.build!(:hero, %{heading: "Welcome"})

          %Version{
            status: :starter,
            sections: [
              %Section{key: "hero", position: 0, children: [], content: %Ash.Union{type: :hero, value: hero}}
            ]
          }
        end

        def version(_pattern), do: %Version{status: :starter, sections: []}
      end

  A starter's keys are fixed strings, so its sections keep their
  identity from one build to the next, and a part with an id takes the
  same id on every build: the editor builds its form from one build and
  the first edit copies another.

  `version/1` never raises. If what it reads can't be read, it logs and
  uses defaults, so the page still renders. `version!/1`, which is
  optional, raises instead. `Billboard.Snapshot` caches starters through
  it, so a starter built from defaults that stand in for unread data
  never outlives the failure. Without it, the cache uses `version/1`.

  A site that names no starter starts every page as an empty version of
  its own version resource, which it names in `resources:`.
  """

  @doc "The starter of the page at `pattern`. Never raises."
  @callback version(Billboard.Site.pattern()) :: struct()

  @doc "Like `version/1`, but raises when what the starter reads can't be read."
  @callback version!(Billboard.Site.pattern()) :: struct()

  @optional_callbacks version!: 1

  # `use Billboard.Site` calls these with the site's `starter:` and the
  # site itself, whose version resource an empty starter is, whichever
  # site is configured.

  @doc false
  def version(nil, _pattern, site), do: empty(site)
  def version(starter, pattern, _site), do: starter.version(pattern)

  @doc false
  def version!(nil, _pattern, site), do: empty(site)

  def version!(starter, pattern, _site) do
    if Code.ensure_loaded?(starter) and function_exported?(starter, :version!, 1),
      do: starter.version!(pattern),
      else: starter.version(pattern)
  end

  defp empty(site) do
    version =
      site.resources()[:version] ||
        raise ArgumentError,
              "#{inspect(site)} names no version resource. Add `version: MySite.Pages.Version` " <>
                "to the `resources:` of its `use Billboard.Site`, naming a module that does " <>
                "`use Billboard.Version`, or give it a `starter:`"

    struct!(version, status: :starter, sections: [])
  end
end
