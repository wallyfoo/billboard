defmodule MySite.Fees do
  @moduledoc """
  What each service costs. It stands in for an Ash resource of the
  site's own, which a real site reads through its domain. Each fee is a
  row as the stock Prices section reads one (`Billboard.Sections.Prices`),
  its `group` the service it's for, so both Prices and the site's own
  Fees draw the same rows.
  """

  @doc "Every fee, in the order the site lists them, its price already formatted."
  def list do
    [
      %{
        id: "f1",
        group: "assessments",
        title: "A first assessment",
        price: "£180",
        unit: "90 minutes"
      },
      %{id: "f2", group: "assessments", title: "A follow-up", price: "£120", unit: "60 minutes"},
      %{
        id: "f3",
        group: "therapy",
        title: "A session",
        price: "£95",
        note: "Online or in person."
      }
    ]
  end
end
