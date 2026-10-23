defmodule Billboard.Parts.Action.Validations.PathOnSite do
  @moduledoc """
  Keeps an action's address on the site: a path starting with one slash.
  Its message gives the site's example path (`Billboard.Site.example_path/0`).
  """
  use Ash.Resource.Validation

  @path ~r{^/(?!/)[A-Za-z0-9._~/#?=&-]*$}

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :path) do
      path when is_binary(path) and path != "" ->
        if Regex.match?(@path, path),
          do: :ok,
          else:
            {:error,
             field: :path,
             message:
               "use an address on this site, starting with /, such as " <>
                 Billboard.Site.example_path()}

      _none ->
        :ok
    end
  end
end
