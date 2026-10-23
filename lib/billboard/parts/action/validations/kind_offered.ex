defmodule Billboard.Parts.Action.Validations.KindOffered do
  @moduledoc """
  Keeps an action's kind to those the site offers (`Billboard.Actions`),
  checked only when the kind changes, as a site option is: an action
  saved with a kind the site has since stopped offering still saves an
  edit to its words.
  """
  use Ash.Resource.Validation

  alias Ash.Changeset

  @impl true
  def validate(changeset, _opts, _context) do
    kind = Changeset.get_attribute(changeset, :kind)

    if Changeset.changing_attribute?(changeset, :kind) and not is_nil(kind) and
         not Billboard.Actions.offered?(kind),
       do: {:error, field: :kind, message: "this site doesn't offer “#{kind}” here"},
       else: :ok
  end
end
