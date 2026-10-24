defmodule Billboard.EditorLive.Messages do
  @moduledoc """
  Turns what the page editor's changes return into sentences for the
  admin: the editor's own reasons, and the first of an Ash error's
  messages, with its variables filled in.
  """

  @doc "A sentence saying why a change didn't save."
  @spec message(term()) :: String.t()
  def message(:gone), do: "That section has gone. This is the page as it is now."
  def message(:nothing_to_share), do: "Every shared section is on this page."

  def message(:stale),
    do: "Someone else changed this section while you were editing it. This is it as it is now."

  def message(%{errors: [first | _]}), do: message(first)

  def message(%{message: text} = error) when is_binary(text) and text != "",
    do: text |> interpolate(Map.get(error, :vars, [])) |> sentence()

  def message(_error), do: "That change didn't save. Try again."

  @doc """
  A field's message in plain words. Ash's own, such as "length must be
  less than or equal to 120", become what to do about it ("Keep this to
  120 characters or fewer."); any other is made a sentence.
  """
  @spec plain(String.t()) :: String.t()
  def plain("length must be less than or equal to " <> most),
    do: "Keep this to #{most} characters or fewer."

  def plain("length must be greater than or equal to 1"), do: "Fill this in."

  def plain("length must be greater than or equal to " <> least),
    do: "Use at least #{least} characters."

  def plain("must be less than or equal to " <> most), do: "Use #{most} or fewer."
  def plain("must be greater than or equal to " <> least), do: "Use #{least} or more."
  def plain("is required"), do: "Fill this in."
  def plain("must be an integer"), do: "Use a whole number."

  # Only a link name has a pattern to match.
  def plain("must match the pattern " <> _pattern),
    do: "Use lowercase letters, numbers, and dashes, starting with a letter."

  def plain(text), do: sentence(text)

  @doc "`text` with a capital first letter and a full stop."
  @spec sentence(String.t()) :: String.t()
  def sentence(text) do
    {first, rest} = String.split_at(text, 1)
    text = String.upcase(first) <> rest
    if String.ends_with?(text, [".", "?", "!"]), do: text, else: text <> "."
  end

  @doc """
  `words` as a list in a sentence, with the serial comma: "Home", "Home
  and Contact", "Home, Contact, and About".
  """
  @spec and_list([String.t()]) :: String.t()
  def and_list([]), do: ""
  def and_list([one]), do: one
  def and_list([one, two]), do: "#{one} and #{two}"

  def and_list(words) do
    {rest, [last]} = Enum.split(words, -1)
    Enum.join(rest, ", ") <> ", and " <> last
  end

  defp interpolate(text, vars) when is_list(vars) do
    Enum.reduce(vars, text, fn
      {key, value}, acc when is_binary(value) or is_number(value) or is_atom(value) ->
        String.replace(acc, "%{#{key}}", to_string(value))

      _var, acc ->
        acc
    end)
  end

  defp interpolate(text, _vars), do: text
end
