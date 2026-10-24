defmodule Billboard.EditorLive.Filler do
  @moduledoc """
  Finds sections that still hold the filler a new section arrives with
  (each component's placeholder, `Billboard.Catalogue.placeholder/1`),
  such as "Your heading", or that a part added in the editor arrives
  with (`Billboard.Sections.Parts.blank/1`), such as "Your link".
  Committing them is allowed, but visitors would read it, so the page
  editor warns about them.

  The filler is read from the site's components as the editor runs,
  since the library compiles before the site does. A component whose
  placeholder reads as finished words, such as the stock News's "What's
  on", says `filler? false` in its `component` section, and its
  placeholder is left out.
  """
  alias Billboard.Catalogue
  alias Billboard.Component.Info
  alias Billboard.Sections.Parts

  # A part added in the editor arrives with words too (`Parts.blank/1`).
  # Only its words count: its address and its kind aren't filler.
  @part_words ~w(label heading body title)

  @doc """
  The filler: the words of every placeholder whose component's
  placeholder is filler (`filler?`, true unless it says), and of every
  part's blank, in the catalogue's order.
  """
  @spec texts() :: [String.t()]
  def texts do
    placeholders =
      for entry <- Catalogue.entries(),
          Info.component_filler?(entry.module),
          text <- strings(entry.placeholder),
          do: text

    blanks =
      for part <- Parts.parts(),
          {field, text} <- Parts.blank(part),
          field in @part_words,
          do: text

    Enum.uniq(placeholders ++ blanks)
  end

  @doc """
  A warning for each section, children of Two columns included, that
  still holds filler. Warnings have the shape of `Billboard.Rule` issues.
  """
  @spec warnings([map()]) :: [Billboard.Rule.issue()]
  def warnings(sections) do
    texts = texts()

    for section <- Enum.flat_map(sections, &[&1 | children(&1)]),
        text = Enum.find(strings(section.content.value), &(&1 in texts)),
        do: %{
          level: :warning,
          key: section.key,
          message: "hasn't been written yet; it still says “#{text}”"
        }
  end

  defp children(%{children: children}) when is_list(children), do: children
  defp children(_section), do: []

  # Every string in a placeholder, or in a section's content, at any
  # depth, skipping Ash's own fields (`__meta__` and the like).
  defp strings(text) when is_binary(text), do: [text]
  defp strings(list) when is_list(list), do: Enum.flat_map(list, &strings/1)
  defp strings(%_{} = struct), do: struct |> Map.from_struct() |> strings()

  defp strings(map) when is_map(map) do
    for {key, value} <- map,
        not (is_atom(key) and String.starts_with?(Atom.to_string(key), "__")),
        text <- strings(value),
        do: text
  end

  defp strings(_value), do: []
end
