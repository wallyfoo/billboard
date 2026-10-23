defmodule Billboard.Parts.Point do
  @moduledoc """
  One of a row of points: a title, a body, and an optional link to a page
  on this site. In Points' cards look, its card is drawn on `surface`, one
  the site offers cards, or on its section's surface when that's `nil`.

  Billboard adds nothing to a part; a part in a list has an id, as
  `Billboard.Component` explains.
  """
  use Ash.Resource, data_layer: :embedded

  alias Billboard.Parts.Point.Validations.LinksOnSite

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  validations do
    validate LinksOnSite
    validate {Billboard.Validations.SurfaceOffered, kind: :card}
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
      constraints max_length: 60
    end

    attribute :body, :string, public?: true, constraints: [max_length: 600]
    attribute :link, Billboard.Parts.Action, public?: true
    attribute :surface, :string, public?: true
  end
end
