defmodule Billboard.Components.Hero.Validations.BindOffered do
  @moduledoc """
  Keeps a hero's binding to those the site offers (`Billboard.Context`),
  or `:none`, checked only when the binding changes, as an action's kind
  is: a hero saved with a binding the site has since stopped offering
  still saves an edit to its words.
  """
  use Ash.Resource.Validation

  alias Ash.Changeset

  @impl true
  def validate(changeset, _opts, _context) do
    bind = Changeset.get_attribute(changeset, :bind)

    if Changeset.changing_attribute?(changeset, :bind) and bind not in [nil, :none] and
         is_nil(Billboard.Context.binding_for(bind)),
       do: {:error, field: :bind, message: "this site doesn't offer “#{bind}” here"},
       else: :ok
  end
end
