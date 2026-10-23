defmodule Billboard.Test.Extension do
  @moduledoc "A Spark extension with nothing in it, to check a component keeps the extensions it's given."
  use Spark.Dsl.Extension, sections: []
end
