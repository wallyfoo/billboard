defmodule Billboard.Directory do
  @moduledoc """
  The pages the builder knows, keyed by route pattern, as the site's
  `pages` section lists them (`Billboard.Site`). The shared-sections
  library is `nil`. A page's `kind` decides which components it may use
  (`Billboard.Catalogue`), and a fixed page lists the sections it must
  have, in order (`Billboard.Directory.Page`).
  """
  alias Billboard.Directory.Page

  @doc "Every page, in the order the admin lists them."
  @spec pages() :: [Page.t()]
  def pages, do: Billboard.Site.pages()

  @doc "The page for route `pattern` (`nil` for the library), or `nil`."
  @spec fetch(String.t() | nil) :: Page.t() | nil
  def fetch(pattern), do: Enum.find(pages(), &(&1.pattern == pattern))

  @doc "Whether the page for route `pattern` has fixed sections. An unknown page has none."
  @spec fixed?(String.t() | nil) :: boolean()
  def fixed?(pattern) do
    case fetch(pattern) do
      %Page{fixed: fixed} -> is_list(fixed)
      nil -> false
    end
  end

  @doc "The page for route `pattern`. Raises `ArgumentError` for an unknown one."
  @spec fetch!(String.t() | nil) :: Page.t()
  def fetch!(pattern),
    do: fetch(pattern) || raise(ArgumentError, "no builder page for #{inspect(pattern)}")

  @doc """
  The page the editor opens when it's given none: `/`, or else the
  site's first page that isn't the library. Raises, naming the fix,
  for a site whose only page is the library.
  """
  @spec home!() :: Page.t()
  def home! do
    pages = pages()

    Enum.find(pages, &(&1.pattern == "/")) ||
      Enum.find(pages, &(&1.kind != :library)) ||
      raise ArgumentError,
            "#{inspect(Billboard.Site.get!())} has no page for the editor to open. " <>
              "Declare `page \"/\", …` in the site's `pages do`"
  end
end
