defmodule Billboard.Parts.Action.Validations.PathOnSite do
  @moduledoc """
  Keeps an action's address on the site: a path starting with one slash.
  Its message gives the site's example path (`Billboard.Site.example_path/0`).
  """
  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute

  @path ~r{^/(?!/)[A-Za-z0-9._~/#?=&-]*$}

  # The error is an exception, not a keyword list: a part in a list is
  # cast with the others through Ash's bulk create, which reports a
  # keyword list as an unknown error rather than an invalid field.
  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :path) do
      path when is_binary(path) and path != "" ->
        if Regex.match?(@path, path),
          do: :ok,
          else:
            {:error,
             InvalidAttribute.exception(
               field: :path,
               message:
                 "use an address on this site, starting with /, such as " <>
                   Billboard.Site.example_path()
             )}

      _none ->
        :ok
    end
  end
end
