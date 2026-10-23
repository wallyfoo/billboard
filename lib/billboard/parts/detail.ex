defmodule Billboard.Parts.Detail do
  @moduledoc """
  One labelled detail, such as "Parking" or "Patch tests". `only_for_group`
  names the page scope it shows on alone (`ctx.context.scope`,
  `Billboard.Context`), or is nil for every page. It keeps the name
  sections have always stored it under.

  Billboard adds nothing to a part; a part in a list has an id, as
  `Billboard.Component` explains.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
      allow_nil? false
      public? true
      constraints max_length: 40
    end

    attribute :body, :string do
      allow_nil? false
      public? true
      constraints max_length: 600
    end

    attribute :only_for_group, :string, public?: true
  end
end
