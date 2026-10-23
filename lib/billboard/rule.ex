defmodule Billboard.Rule do
  @moduledoc """
  A page rule a site adds to the stock ones, such as "never the same
  ground twice in a row". A site lists its rules in its module's
  `rules/0` (`Billboard.Site`), and the builder runs them after its own.

  `check/3` reads a page's sections in memory and returns issues: an
  `:error` holds Publish back, and a `:warning` only advises. Each issue
  names the section it's about by `key`, or `nil` when it's about the
  whole page. A rule never touches the database, so the editor can check
  a draft as it changes.

  It takes the page, its top-level sections in order, and `shared`, the
  shared library's sections by key, so a rule can see what a shared
  section draws. The page is the site's directory entry
  (`Billboard.Directory.Page`), and the sections are the site's own
  section structs; a rule reads them through `Billboard.Rules`'
  `everything/1`, `type/1`, `effective_type/2`, and `actions_of/1`.
  `error/2` and `warning/2` need only a section's `:key`.

      defmodule MySite.Rules do
        @behaviour Billboard.Rule

        # Compares the surface each section is drawn on, so `nil`, or a
        # name the site has stopped offering, counts as its kind's default.
        @impl true
        def check(_page, sections, _shared) do
          sections
          |> Enum.map(&{&1, Billboard.Surfaces.resolve(&1.content.type, &1.surface)})
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.flat_map(fn
            [{_, ground}, {section, ground}] ->
              [Billboard.Rule.error(section, "two sections in a row can't share a ground")]

            _ ->
              []
          end)
        end
      end
  """

  @typedoc "One problem with a page: how serious it is, the section it's about, and what to say."
  @type issue :: %{level: :error | :warning, key: String.t() | nil, message: String.t()}

  @doc """
  Every issue with `sections` on `page`. `shared` is the shared library's
  sections, by key.
  """
  @callback check(
              page :: Billboard.Directory.Page.t(),
              sections :: [map()],
              shared :: %{optional(String.t()) => map()}
            ) :: [issue()]

  @doc "An error about `section`, or about the whole page when it's `nil`."
  @spec error(map() | nil, String.t()) :: issue()
  def error(section, message), do: issue(:error, section, message)

  @doc "A warning about `section`, or the whole page when it's `nil`."
  @spec warning(map() | nil, String.t()) :: issue()
  def warning(section, message), do: issue(:warning, section, message)

  defp issue(level, section, message) when is_binary(message),
    do: %{level: level, key: section && Map.fetch!(section, :key), message: message}
end
