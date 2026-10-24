defmodule Billboard.Test.WrappedAction do
  @moduledoc "Billboard's action under a name of a site's own, as an `Ash.Type.NewType`."
  use Ash.Type.NewType, subtype_of: Billboard.Parts.Action
end
