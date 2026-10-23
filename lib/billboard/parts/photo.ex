defmodule Billboard.Parts.Photo do
  @moduledoc """
  A photograph, or the placeholder that stands in for one. `label` says
  what the shot shows and is drawn on the placeholder; `path` points at an
  upload, under /uploads, where `Billboard.Uploads` serves them; `alt`
  describes the upload for people who can't see it.

  Billboard adds nothing to a part; a part in a list has an id, as
  `Billboard.Component` explains.
  """
  use Ash.Resource, data_layer: :embedded

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  validations do
    validate match(:path, ~r{^/uploads/[\w.-]+$}) do
      where present(:path)
      message "upload a photograph here rather than linking one"
    end

    validate present(:alt) do
      where present(:path)
      message "describe the photograph for people who can't see it"
    end
  end

  attributes do
    attribute :label, :string do
      allow_nil? false
      public? true
      constraints max_length: 80
    end

    attribute :path, :string, public?: true
    attribute :alt, :string, public?: true, constraints: [max_length: 160]
  end
end
