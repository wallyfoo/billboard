defmodule Billboard.Test.Actions do
  @moduledoc """
  The test site's action kinds: a visit, only on item pages, placed
  before the link, and a call the site words itself.
  """
  @behaviour Billboard.Actions
  use Phoenix.Component

  @impl true
  def kinds,
    do: [
      visit: [label: "Visit the shop", only_on: [:item]],
      link: [],
      call: [label: "Call the shop", words: :site]
    ]

  @impl true
  def label_hint, do: "A visit left blank says “Visit”."

  @impl true
  def action(%{action: %{kind: :visit}} = assigns) do
    ~H"""
    <a id={@prefix && "#{@prefix}-visit"} class="test-visit" href="/visit">
      {@action.label || "Visit"}
    </a>
    """
  end

  def action(%{action: %{kind: :call}} = assigns) do
    ~H"""
    <a class="test-call" href={"tel:" <> (@ctx[:site][:phone] || "")}>Call us</a>
    """
  end
end
