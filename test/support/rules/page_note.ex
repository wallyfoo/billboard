defmodule Billboard.Test.PageNote do
  @moduledoc """
  A site rule that always has something to say: a warning about the
  whole page, so a test can see where the site's issues fall.
  """
  @behaviour Billboard.Rule

  @impl true
  def check(_page, _sections, _shared), do: [Billboard.Rule.warning(nil, "a note on the page")]
end
