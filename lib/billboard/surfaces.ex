defmodule Billboard.Surfaces do
  @moduledoc """
  The surfaces the site offers its sections. A surface is a ground and the
  ink that reads on it, drawn by the `bb-surface-NAME` class. A section
  records one by name in its `surface`, where `nil` means its kind's
  default.

  The site names its surfaces, in order, in its module's `surfaces/0`
  (`Billboard.Site`). The first is the page's own.

  Every section has a kind (`kind/1`), which its component declares as
  `surface_kind`, and the site offers each kind its own surfaces, in order,
  in `offered/0` (`offered/1` here). The first is the kind's default
  (`default/1`). A kind offered one surface never has a choice to make.

  Some sections never choose (`taken_from/2`). A component's
  `surface_from` says where it takes its surface from instead: a
  `:library` section is drawn on its library section's surface, and a
  `:layout` one on whatever the site's layout draws it on. A column sits
  on its parent's surface.

  A card inside a section may be drawn on a surface of its own, from the
  `:card` kind's offer (`card/1`). Unlike a section's kind, that one may
  be offered nothing, since a card that names no surface is drawn on its
  section's.

  `offered/1` raises for a section's kind offered nothing, and for an
  offer that names a surface the site doesn't list, so a typo fails where
  it's read rather than drawing a section on no ground. A site that
  leaves `:card` out of its offer offers cards none.
  """

  alias Billboard.Component.Info
  alias Billboard.Site

  @typedoc """
  What a section is to its page, which decides the surfaces it may take:
  `:page` sits on the page's own ground, and `:stand_out` breaks from it.
  `:card` is the kind of a card inside a section, which may be offered
  none. A site may offer more kinds.
  """
  @type kind :: :page | :stand_out | :card | atom()

  @typedoc """
  Where a section that never chooses its surface takes it from: its
  library section, the layout, or its parent.
  """
  @type source :: :library | :layout | :parent

  # The kinds a site may offer nothing. A section needs a ground, but a
  # card that names none is drawn on its section's.
  @may_be_empty [:card]

  @doc "The site's surfaces, in order. The first is the page's own."
  @spec all() :: [Site.surface()]
  def all, do: Site.get!().surfaces()

  @doc """
  The names a section, or a card, of `kind` may take, in order. It's never
  empty for a section's kind: it raises for one the site offers nothing,
  and for an offer naming a surface the site doesn't list, since either is
  a mistake in the site's module. The `:card` kind may be offered none.
  """
  @spec offered(kind()) :: [String.t()]
  def offered(kind) do
    case Keyword.get(Site.get!().offered(), kind, []) do
      [] when kind in @may_be_empty ->
        []

      [] ->
        raise ArgumentError,
              "the site offers no surfaces for the kind #{inspect(kind)}. Add " <>
                "`#{kind}: [...]` to its offered/0, naming at least one of its surfaces"

      names ->
        listed = Enum.map(all(), & &1.name)

        case Enum.reject(names, &(&1 in listed)) do
          [] ->
            names

          [unlisted | _] ->
            raise ArgumentError,
                  "the site offers #{inspect(kind)} the surface “#{unlisted}”, " <>
                    "which isn't among its surfaces. Add it to the site's surfaces/0, " <>
                    "or take it out of offered/0"
        end
    end
  end

  @doc """
  The surface a section of `kind` takes when it names none. A card has no
  default of its own, since it takes its section's, so `:card` raises.
  """
  @spec default(kind()) :: String.t()
  def default(kind) when kind in @may_be_empty,
    do: raise(ArgumentError, "#{inspect(kind)} isn't a section's kind, so it has no default")

  def default(kind), do: kind |> offered() |> hd()

  @doc """
  The surface a section whose content is `type` is drawn on, given the
  `surface` it records: that one while its kind is offered it, and its
  kind's default otherwise, for `nil` or a name the site has stopped
  offering. Copying a section doesn't check its surface again, so a page
  is never locked out of the editor by one, and this is what keeps such a
  section on a ground the site still has.
  """
  @spec resolve(atom(), String.t() | nil) :: String.t()
  def resolve(type, surface) when is_atom(type) do
    kind = kind(type)
    if surface in offered(kind), do: surface, else: default(kind)
  end

  @doc """
  The surface a card is drawn on, given the `surface` it records: that one
  while the site offers cards it, and `nil` otherwise, for `nil` or a name
  the site has stopped offering, which draws the card on its section's
  surface.
  """
  @spec card(String.t() | nil) :: String.t() | nil
  def card(surface), do: if(surface in offered(:card), do: surface)

  @doc """
  The kind of a section whose content is `type`: its component's
  `surface_kind`, which is `:page` unless the component says otherwise.
  Raises for a type the site has no component for.

  A section that takes its surface from a library section is its own
  component's kind too. Its library section records its own surface, and
  which kind that is can't be told from the type alone.
  """
  @spec kind(atom()) :: kind()
  def kind(type) when is_atom(type),
    do: type |> Site.component!() |> Info.component_surface_kind!()

  @doc """
  Where a section takes its surface from when it can't choose one, or
  `nil` when it chooses its own. `type` is its content's type, and
  `parent_id` its parent's, which only a column has. Without a parent, it
  raises for a type the site has no component for, as `kind/1` does.
  """
  @spec taken_from(atom(), String.t() | nil) :: source() | nil
  def taken_from(_type, parent_id) when is_binary(parent_id), do: :parent

  def taken_from(type, nil) when is_atom(type),
    do: type |> Site.component!() |> Info.component_surface_from!()

  @doc """
  Whether a section of `type`, under `parent_id`, chooses its own surface.
  Without a parent, it raises for a type the site has no component for,
  as `kind/1` does.
  """
  @spec choosable?(atom(), String.t() | nil) :: boolean()
  def choosable?(type, parent_id), do: taken_from(type, parent_id) == nil
end
