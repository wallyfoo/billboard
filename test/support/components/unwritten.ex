defmodule Billboard.Test.Unwritten do
  @moduledoc """
  A component whose renderer types its title in place but draws its note
  as plain text, so `Billboard.ComponentCase` names the note. It's on the
  shop, kept off every page's palette by the shop's `kinds:`.
  """
  use Billboard.Component

  component do
    key :unwritten
    label "Unwritten"
    hint "Words it never draws."
    category :content
    renderer Billboard.Test.UnwrittenRenderer
    placeholder %{title: "x", note: "y"}
  end

  editor do
    words :title, label: "Title"
    words :note, label: "Note"
  end

  attributes do
    attribute :title, :string, public?: true
    attribute :note, :string, public?: true
  end
end
