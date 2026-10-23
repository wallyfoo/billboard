defmodule Billboard.Validations.SurfaceOffered do
  @moduledoc """
  Keeps a surface `field` to the ones the site offers `kind`
  (`Billboard.Surfaces.offered/1`), or `nil`. Use it in a part whose card
  may be drawn on a surface of its own:

      validations do
        validate {Billboard.Validations.SurfaceOffered, kind: :card}
      end

  `field:` is the attribute holding the surface's name, `:surface` by
  default. `kind:` is required.

  `nil` is always allowed: a card that names no surface is drawn on its
  section's.

  It checks only when the surface changes. A part keeps a surface the
  site has stopped offering, so editing its words never fails over a
  choice nobody made just now, and `Billboard.Surfaces.card/1` draws it on
  its section's surface in the meantime.
  """
  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidAttribute
  alias Billboard.Surfaces

  @impl true
  def init(opts) do
    cond do
      not is_atom(opts[:kind]) or is_nil(opts[:kind]) ->
        {:error,
         "SurfaceOffered needs the kind whose offer it keeps to, as `kind:`, such as " <>
           "`validate {Billboard.Validations.SurfaceOffered, kind: :card}`"}

      not is_atom(Keyword.get(opts, :field, :surface)) ->
        {:error, "SurfaceOffered's `field:` must name an attribute, such as `field: :surface`"}

      true ->
        {:ok, Keyword.put_new(opts, :field, :surface)}
    end
  end

  # The error is an exception, not a keyword list: a part in a list is
  # cast with the others through Ash's bulk create, which reports a
  # keyword list as an unknown error rather than an invalid field.
  @impl true
  def validate(changeset, opts, _context) do
    field = opts[:field]
    surface = Ash.Changeset.get_attribute(changeset, field)

    if is_nil(surface) or not Ash.Changeset.changing_attribute?(changeset, field) or
         surface in Surfaces.offered(opts[:kind]) do
      :ok
    else
      {:error,
       InvalidAttribute.exception(
         field: field,
         message: "“#{surface}” isn't a surface the site offers here"
       )}
    end
  end
end
