defmodule Billboard.Test.Layout do
  @moduledoc """
  The shop's chrome: a header and a footer naming the shop
  (`site.name`), the hero block on the loud surface, the sections in
  `<main>`, and the info flash, when not editing.
  """
  use Phoenix.Component

  @behaviour Billboard.Layout

  attr :flash, :map, required: true
  attr :site, :map, required: true
  attr :current_path, :string, default: nil
  attr :editing, :boolean, default: false
  slot :hero, required: true
  slot :inner_block, required: true

  @impl true
  def page(assigns) do
    ~H"""
    <header id="shop-header" data-path={@current_path}>{@site.name}</header>
    <div class="bb-surface-loud">{render_slot(@hero)}</div>
    <main>{render_slot(@inner_block)}</main>
    <footer id="shop-footer">{@site.name}, since today</footer>
    <p :if={!@editing && Phoenix.Flash.get(@flash, :info)} id="shop-flash">
      {Phoenix.Flash.get(@flash, :info)}
    </p>
    """
  end

  @impl true
  def site, do: %{name: "The shop"}
end
