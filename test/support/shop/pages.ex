defmodule Billboard.Test.Shop.Pages do
  @moduledoc "The shop's domain for its pages, with AshPhoenix's forms, as a site's is."
  use Billboard.Domain, site: Billboard.Test.Shop, extensions: [AshPhoenix]
end
