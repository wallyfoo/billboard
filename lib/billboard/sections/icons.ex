defmodule Billboard.Sections.Icons do
  @moduledoc """
  The icons stock sections and the editor draw: Heroicons, by name, as
  `<span class="hero-x-mark-mini size-4">`. The Heroicons Tailwind
  plugin a site has from `mix phx.new` (`@plugin "../vendor/heroicons"`
  in `app.css`) draws them, from the names it finds in its sources,
  billboard's `lib` among them.
  """
  use Phoenix.Component

  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  @doc "A Heroicon, such as `hero-x-mark-mini`."
  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} aria-hidden="true" />
    """
  end
end
