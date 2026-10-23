defmodule Billboard.Changes.SiteOptions do
  @moduledoc """
  Applies the site's options (`Billboard.SiteOptions`) to a component as
  it's created or updated. Billboard adds it to every component as a
  global change, `on: [:create, :update]`, so a component doesn't opt in,
  field by field, and a site's offer holds wherever the component is
  saved, inside a section's content union or on its own.

  For the fields the site names for the component's type, it does two
  things.

  **Defaults, on create only.** A field with a list offer that the params
  don't give takes the offer's first, the site's default. A value the
  params give is never replaced, even when it's the component's own
  default. Ash sets static attribute defaults before any change runs, so
  a field the params leave out arrives here already changing, listed in
  `changeset.defaults`; a field with no default, or a function default
  that Ash sets later, arrives not changing. Either counts as not given.
  An update never applies a default, since the section already holds a
  value.

  **Offers.** A field being changed must keep to the offer.

    * For a list offer, a value the site doesn't offer is refused with
      "this site doesn't offer “VALUE” here". `nil` is left to the
      attribute: it's allowed where the attribute allows it, and the
      attribute's own error refuses it where it doesn't.
    * For a range offer, a save is refused when the list grows past the
      range's last ("this site shows at most N here") or shrinks below its
      first ("this site needs at least N here"), measured against the
      stored list, with `nil` counted as empty. A create measures against
      an empty list, so it's refused only for growing past the last: a
      new section whose list nobody has filled in yet still saves.

  It checks only when the field changes, as a section's surface is
  checked only when it changes. A section keeps a value the site has
  stopped offering, so editing its words never fails over a choice
  nobody made just now; its renderer draws what the site still offers in
  its place (`Billboard.SiteOptions.resolved/2`). A new section built
  from `Billboard.SiteOptions.placeholder/1` is never refused for its
  placeholder, since that leaves out what the site doesn't offer. For the same reason a
  list the site has since narrowed still saves an edit to one of its
  items, and may shrink towards the range, but never grows further from
  it.

  Each refusal is an ordinary changeset error on the field, as a
  validation's `{:error, field: field, message: message}` is, so it's
  reported the same way through the section's content union.
  """
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Billboard.Component.Info
  alias Billboard.SiteOptions

  @impl true
  def change(changeset, _opts, _context) do
    type = Info.component_key!(changeset.resource)

    case SiteOptions.narrowed(type) do
      [] ->
        changeset

      narrowed ->
        changeset = Enum.reduce(narrowed, changeset, &put_default/2)
        Enum.reduce(narrowed, changeset, &check/2)
    end
  end

  defp put_default({field, [first | _]}, %{action_type: :create} = changeset) do
    if given?(changeset, field),
      do: changeset,
      else: Changeset.force_change_attribute(changeset, field, first)
  end

  defp put_default(_offer, changeset), do: changeset

  defp given?(changeset, field),
    do: Changeset.changing_attribute?(changeset, field) and field not in changeset.defaults

  defp check({field, offer}, changeset) do
    if Changeset.changing_attribute?(changeset, field) do
      case refusal(offer, changeset, field) do
        nil ->
          changeset

        message ->
          Changeset.add_error(changeset,
            field: field,
            message: message,
            value: Changeset.get_attribute(changeset, field)
          )
      end
    else
      changeset
    end
  end

  defp refusal(%Range{first: first, last: last}, changeset, field) do
    now = changeset |> Changeset.get_attribute(field) |> count()

    was =
      if changeset.action_type == :create,
        do: 0,
        else: changeset |> Changeset.get_data(field) |> count()

    cond do
      now > last and now > was -> "this site shows at most #{last} here"
      now < first and now < was -> "this site needs at least #{first} here"
      true -> nil
    end
  end

  defp refusal(values, changeset, field) do
    case Changeset.get_attribute(changeset, field) do
      nil ->
        nil

      value ->
        if value not in values,
          do: "this site doesn't offer “#{SiteOptions.show(value)}” here"
    end
  end

  defp count(nil), do: 0
  defp count(list) when is_list(list), do: length(list)
end
