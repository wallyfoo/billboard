defmodule Billboard.Test.Broken.DistinctTitles do
  @moduledoc "Refuses two points with the same title, for `Billboard.Test.Broken.Repeated`."
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    titles =
      changeset
      |> Ash.Changeset.get_attribute(:points)
      |> List.wrap()
      |> Enum.map(& &1.title)

    if titles == Enum.uniq(titles),
      do: :ok,
      else: {:error, field: :points, message: "give each point a title of its own"}
  end
end
