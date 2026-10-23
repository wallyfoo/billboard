defmodule Billboard.Parts.Action do
  @moduledoc """
  A button or text link. `kind` says where it goes: `:link` to `path`,
  an address on the site, or one of the site's own kinds
  (`Billboard.Actions`), which it lists and draws.

  `style` is `:primary`, `:secondary`, or `:text`. A section should have
  one primary at most; `Billboard.Rules` warns otherwise.

  Billboard adds nothing to a part; a part in a list has an id, as
  `Billboard.Component` explains.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  validations do
    validate Billboard.Parts.Action.Validations.KindOffered

    validate present([:label, :path]) do
      where attribute_equals(:kind, :link)
      message "a link needs a label and an address"
    end

    validate Billboard.Parts.Action.Validations.PathOnSite
  end

  attributes do
    uuid_primary_key :id

    # The site's kinds aren't known when billboard compiles, so `kind`
    # has no `one_of`; `KindOffered` checks it against the site's.
    attribute :kind, :atom do
      allow_nil? false
      default :link
      public? true
    end

    attribute :style, :atom do
      allow_nil? false
      default :secondary
      public? true
      constraints one_of: [:primary, :secondary, :text]
    end

    attribute :label, :string, public?: true, constraints: [max_length: 40]
    attribute :path, :string, public?: true, constraints: [max_length: 200]
  end
end
