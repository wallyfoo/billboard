defmodule MySite.Sections.Fees do
  @moduledoc """
  The site's fees, read from one source, under a title: every fee, or
  only those of the service the page is about.
  """
  use Billboard.Component

  # guide:component
  component do
    key :fees
    label "Fees"
    hint "What each service costs."
    category :data
    renderer MySiteWeb.Sections.Fees
    context [:scope]
    filler? false
    placeholder %{title: "Fees"}
  end

  editor do
    words :title, label: "Title", limit: 60
    field :only_service, as: :choice, from: :services, label: "Shows"
  end

  attributes do
    attribute :title, :string, public?: true, constraints: [max_length: 120]
    attribute :only_service, :string, public?: true
  end

  # guide:end
end
