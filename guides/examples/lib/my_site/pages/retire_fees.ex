defmodule MySite.Pages.RetireFees do
  @moduledoc """
  Retires the site's own Fees (`MySite.Sections.Fees`) in favour of the
  stock Prices (`Billboard.Components.Prices`), which draws the same
  rows: every stored Fees section, live, drafted, or in the library,
  becomes a Prices section, or, with `delete/1`, goes. A script, or a
  release's `rpc`, runs one of them once.
  """

  # guide:migrate
  @doc """
  Moves every Fees section to Prices. Its title becomes the head's
  heading, a service it chose becomes the group, and "Only this page's
  service" becomes "Only this page's group".
  """
  def to_prices(opts \\ []) do
    Billboard.Pages.migrate_sections(:fees, &prices/1, opts)
  end

  # `fees` is a section's stored fields, by name, as strings.
  defp prices(fees) do
    {:prices,
     %{
       head: fees["title"] && %{heading: fees["title"]},
       group: fees["service"],
       this_page_only: fees["this_service_only"] == true
     }}
  end

  # guide:end

  # guide:delete
  @doc "Takes every Fees section off every page."
  def delete(opts \\ []) do
    Billboard.Pages.migrate_sections(:fees, fn _fees -> :delete end, opts)
  end

  # guide:end
end
