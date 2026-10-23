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
  section draws. Until step 5 the pages and sections are the site's own
  structs, so they're typed loosely here; a section needs only a `:key`
  for `error/2` and `warning/2`.

      defmodule MySite.Rules do
        @behaviour Billboard.Rule

        @impl true
        def check(_page, sections, _shared) do
          for [a, b] <- Enum.chunk_every(sections, 2, 1, :discard), a.surface == b.surface,
              do: Billboard.Rule.error(b, "two sections in a row can't share a ground")
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
              page :: struct(),
              sections :: [struct()],
              shared :: %{optional(String.t()) => struct()}
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
