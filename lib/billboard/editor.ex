defmodule Billboard.Editor do
  @moduledoc "The page editor's addresses, from where the site's router mounts it (`Billboard.Editor.Router`)."

  @library_param "shared"

  @doc """
  The editor's address for the page at route `pattern` (`nil` for the
  shared library), in `router`, with `open: key` the section it opens.
  Raises, naming the fix, when the router doesn't mount the editor.
  """
  @spec path(module(), String.t() | nil, keyword()) :: String.t()
  def path(router, pattern, opts \\ []) do
    # `open` before `page`, as `~p` gave them, which sorts them.
    query = Keyword.take(opts, [:open]) ++ [page: pattern || @library_param]
    mount(router).path <> "?" <> URI.encode_query(query)
  end

  @doc false
  def library_param, do: @library_param

  @doc "Where the router mounts the editor, and its back link."
  @spec mount(module()) :: %{path: String.t(), back: {String.t(), String.t()}}
  def mount(router) do
    Enum.find_value(Phoenix.Router.routes(router), & &1.metadata[:billboard_editor]) ||
      raise ArgumentError,
            "#{inspect(router)} doesn't mount the page editor. Add `billboard_editor \"/pages\"` " <>
              "inside its signed-in live_session, with `import Billboard.Editor.Router`"
  end
end
