defmodule MySite.Pages.Data do
  @moduledoc """
  What the site's pages read for the sections that draw rows: the fees,
  read once for every Fees section on a page.
  """
  @behaviour Billboard.Data

  @impl true
  def fetch(%MySite.Sections.Fees{}, _context, loaded),
    do: Billboard.Data.once(loaded, :fees, &MySite.Fees.list/0)

  def fetch(_content, _context, _loaded), do: :none
end
