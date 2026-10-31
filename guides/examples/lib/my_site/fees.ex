defmodule MySite.Fees do
  @moduledoc """
  What each service costs. It stands in for an Ash resource of the
  site's own, which a real site reads through its domain.
  """

  @doc "Every fee, in the order the site lists them."
  def list do
    [
      %{id: "f1", service: "assessments", title: "A first assessment", price: "£180"},
      %{id: "f2", service: "assessments", title: "A follow-up", price: "£120"},
      %{id: "f3", service: "therapy", title: "A session", price: "£95"}
    ]
  end
end
