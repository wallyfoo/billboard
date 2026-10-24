defmodule Billboard.Test.Broken.Repeated do
  @moduledoc """
  A component whose points must each have a title of their own, so a
  point added beside its placeholder's, which starts as the same blank
  title, is refused, though a list of the blank alone builds. For
  `Billboard.ComponentCase`.
  """
  use Billboard.Component

  component do
    key :repeated
    label "Repeated"
    hint "Points that may not repeat."
    category :content
    renderer Billboard.Test.Broken.BareRenderer
    placeholder %{points: [%{title: "Your point"}]}
    parts :points, Billboard.Parts.Point, min: 1, max: 4
  end

  editor do
    field :points, as: :list, part: :point, min: 1, max: 4, item_label: "point"
  end

  validations do
    validate Billboard.Test.Broken.DistinctTitles
  end
end
