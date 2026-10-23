defmodule Billboard.Pages do
  @moduledoc """
  The page engine's functions. Each page has at most two versions: the
  live one, and a draft of uncommitted changes. A page's record is made
  on its first edit. The site's domain (`Billboard.Domain`) delegates
  these by the same names, so a site calls `MySite.Pages.page_for/1`.

  They reach the site's resources through its domain's code interfaces
  (`Billboard.Site.domain!/0`), which `use Billboard.Domain` defines.
  """

  alias Billboard.Site

  @doc """
  The page record for `pattern` (`nil` for the library), made if it has
  none. A page's first edit makes it, through `Billboard.Version.Edit`.
  """
  def ensure_page(pattern, opts \\ []) do
    case existing_page(pattern, opts) do
      {:ok, nil} -> domain().create_page(%{pattern: pattern}, opts)
      other -> other
    end
  end

  defp existing_page(nil, opts), do: domain().fetch_library_page(opts)
  defp existing_page(pattern, opts), do: domain().fetch_page(pattern, opts)

  defp domain, do: Site.domain!()
end
