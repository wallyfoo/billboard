defmodule Billboard.Sections.EditorFields do
  @moduledoc """
  Reads a section's editor fields from its component's `editor` section
  (`Billboard.Component.Info.editor_fields/1`), an ordered keyword list
  of field names and options, for the editor and the renderers. `:as`
  says what each is; `Billboard.Component`'s "How the editor changes it"
  describes each kind, with the options it takes. The drawing of the
  fields the editor doesn't type into on the page comes with the editor.

  Fields are named by their path inside the content, such as
  `head.action` or `points.1.link`. `resolve/2` turns a path back into a
  field, refusing any the specs don't describe; `words/2` does the same for
  a words field, which the inline editor types into, and `hidden_at?/3`
  says whether the field at a path is left out now, so words a binding
  or a layout leaves out can be refused.
  """
  alias Billboard.{Context, Markdown, SiteOptions}
  alias Billboard.Sections.Parts

  @variant_labels %{
    text_only: "Text only",
    media_left: "Photograph left",
    media_right: "Photograph right",
    heading: "Heading",
    quote_left: "Quote left",
    quote_right: "Quote right",
    even: "Even",
    wide_left: "Wide left",
    wide_right: "Wide right"
  }

  # The controls header is a single row, so its words are shorter.
  @short_variant_labels %{
    text_only: "No photo",
    media_left: "Photo left",
    media_right: "Photo right"
  }

  @doc """
  The editor fields of a section whose content is `type`, as its
  component's `editor` section declares them
  (`Billboard.Component.Info.editor_fields/1`), before the site narrows
  them.
  """
  @spec specs(atom()) :: keyword()
  def specs(type),
    do: type |> Billboard.Site.component!() |> Billboard.Component.Info.editor_fields()

  @doc """
  The names of every set of choices the site's components and the parts
  pick from (`from:`), for the editor to read once (`Billboard.Context.choices_for/1`).
  """
  @spec choice_names() :: [atom()]
  def choice_names do
    components =
      Enum.flat_map(Billboard.Site.components(), &Billboard.Component.Info.editor_fields/1)

    parts = Enum.flat_map(Parts.parts(), &Parts.editor_fields/1)

    for {_field, spec} <- components ++ parts, from = spec[:from], uniq: true, do: from
  end

  @doc """
  The editor fields of a section whose content is `type`, its
  component's (`specs/1`), narrowed to what the site offers
  (`Billboard.SiteOptions`). It narrows selects, variants, and list
  lengths only:

    * each `:select` keeps only the options the site offers, in the
      component's order;
    * each `:variants` keeps only the layouts the site offers, in the
      component's order;
    * each `:list` the site narrows to a range of lengths has its `max`
      lowered to the range's last, and its `min` raised to the range's
      first, so the editor neither adds an item nor offers to remove one
      that a save would refuse.

  A select or variants left with one option is a choice the site has
  made, which the editor doesn't draw. Every other field, such as a
  `:number` or a `:toggle`, is as the component has it.
  """
  @spec narrowed(atom()) :: keyword()
  def narrowed(type) when is_atom(type) do
    lengths =
      for {field, %Range{} = range} <- SiteOptions.narrowed(type), into: %{}, do: {field, range}

    for {field, spec} <- specs(type) do
      case Keyword.get(spec, :as) do
        :select ->
          {field, Keyword.update!(spec, :options, &SiteOptions.options(type, field, &1))}

        :variants ->
          {field,
           Keyword.update!(spec, :options, fn variants ->
             Enum.filter(variants, &SiteOptions.offers?(type, field, &1))
           end)}

        :list ->
          case Map.fetch(lengths, field) do
            {:ok, first..last//_} -> {field, spec |> lower_max(last) |> raise_min(first)}
            :error -> {field, spec}
          end

        _other ->
          {field, spec}
      end
    end
  end

  defp lower_max(spec, max),
    do: Keyword.update(spec, :max, max, &min(&1, max))

  # A list with no `min` has none, so a range from 0 leaves it as it is.
  defp raise_min(spec, min) do
    if min > Keyword.get(spec, :min, 0),
      do: Keyword.update(spec, :min, min, fn _min -> min end),
      else: spec
  end

  @doc """
  Whether `spec` is left out of `form` now: by its `hide_when`, or, with
  `bound: :hide`, while the section's binding replaces its own words
  (`Billboard.Context.replaces_words?/1`).
  """
  def hidden?(form, spec) do
    Enum.any?(Keyword.get(spec, :hide_when, []), fn {field, values} ->
      to_string(form[field].value) in Enum.map(values, &to_string/1)
    end) or (spec[:bound] == :hide and Context.replaces_words?(form[:bind].value))
  end

  @doc """
  `specs` with each `:binding_note` made the note of the binding `form`
  names, with its link, or left out when that binding says nothing.
  """
  def binding_notes(specs, form) do
    Enum.flat_map(specs, fn
      {field, spec} when is_list(spec) ->
        if spec[:as] == :binding_note,
          do: binding_note(field, form),
          else: [{field, spec}]
    end)
  end

  defp binding_note(field, form) do
    with {_name, opts} <- Context.binding_for(form[:bind].value),
         note when is_binary(note) <- opts[:note] do
      [{field, [as: :note, text: note] ++ Keyword.take(opts, [:link])}]
    else
      _none -> []
    end
  end

  @doc "Whether `spec`'s words are offered under More, by its `more`."
  def more?(spec), do: Keyword.get(spec, :more, false)

  @doc """
  The field a path names (`["points", "1", "link"]`), as the form path
  under the content (`[:points, 1, :link]`), with its spec. Only a `:part`
  or `:list` field resolves, and only through the specs, so a path from
  the browser can't reach anything else.
  """
  @spec resolve(keyword(), [String.t()]) :: {:ok, list(), keyword()} | :error
  def resolve(specs, path), do: find(specs, path, [:part, :list])

  @doc """
  The words field a words path names (`"points.1.body"`), as the form path
  under the content (`[:points, 1, :body]`), with its spec. Only a `:text`
  or `:markdown` field resolves, and only through the specs, as `resolve/2`
  does, so a path from the browser can't reach a setting.
  """
  @spec words(keyword(), String.t()) :: {:ok, list(), keyword()} | :error
  def words(specs, path) when is_binary(path) do
    find(specs, String.split(path, "."), [:text, :markdown])
  end

  # Follows `path` through the specs, into parts and list items, to a field
  # drawn as one of `kinds`.
  defp find(specs, [name | rest], kinds) do
    with {field, spec} <- Enum.find(specs, fn {field, _spec} -> Atom.to_string(field) == name end) do
      descend(field, spec, rest, kinds)
    else
      nil -> :error
    end
  end

  defp find(_specs, [], _kinds), do: :error

  defp descend(field, spec, [], kinds) do
    if Keyword.get(spec, :as, :text) in kinds, do: {:ok, [field], spec}, else: :error
  end

  defp descend(field, spec, [index | rest], kinds) do
    with :list <- spec[:as],
         {index, ""} <- Integer.parse(index),
         [_ | _] <- rest,
         {:ok, path, inner} <- find(Parts.editor_fields(spec[:part]), rest, kinds) do
      {:ok, [field, index | path], inner}
    else
      _not_a_list_item -> descend_part(field, spec, [index | rest], kinds)
    end
  end

  defp descend_part(field, spec, rest, kinds) do
    with :part <- spec[:as],
         {:ok, path, inner} <- find(Parts.editor_fields(spec[:part]), rest, kinds) do
      {:ok, [field | path], inner}
    else
      _other -> :error
    end
  end

  @doc """
  The content's form under the section's `form` (a `Phoenix.HTML.Form`),
  as the editor draws it.
  """
  def content_form(form) do
    [content] = Phoenix.HTML.FormData.to_form(form.source, form, :content, [])
    content
  end

  @doc """
  The form of the part or list item at `at` (`[:points, 1]`, `[:head,
  :action]`) under `form` (a `Phoenix.HTML.Form`), as the editor draws it,
  or nil if `form` hasn't got it.
  """
  def sub_form(form, []), do: form

  def sub_form(form, [field, index | rest]) when is_integer(index) do
    case form |> nested_forms(field) |> Enum.at(index) do
      nil -> nil
      item -> sub_form(item, rest)
    end
  end

  def sub_form(form, [field | rest]) do
    case nested_forms(form, field) do
      [part | _] -> sub_form(part, rest)
      [] -> nil
    end
  end

  defp nested_forms(form, field), do: Phoenix.HTML.FormData.to_form(form.source, form, field, [])

  @doc """
  Whether the field at `at` under the content (`[:quote, :body]`) is left
  out now: by its own spec, or by that of a part or list holding it, each
  read on its holder's form (`hidden?/2`), as the editor draws them.
  `form` is the content's (`content_form/1`), and `specs` its fields. A
  field the specs don't name, or a holder `form` hasn't got, is left out.
  """
  def hidden_at?(_form, _specs, []), do: true

  def hidden_at?(form, specs, [field | rest]) do
    case List.keyfind(specs, field, 0) do
      {^field, spec} -> hidden?(form, spec) or hidden_within?(form, field, spec, rest)
      nil -> true
    end
  end

  defp hidden_within?(_form, _field, _spec, []), do: false

  defp hidden_within?(form, field, spec, rest) do
    {holder, rest} =
      case {spec[:as], rest} do
        {:list, [index | rest]} when is_integer(index) -> {[field, index], rest}
        _part -> {[field], rest}
      end

    case sub_form(form, holder) do
      %Phoenix.HTML.Form{} = holder -> hidden_at?(holder, Parts.editor_fields(spec[:part]), rest)
      nil -> true
    end
  end

  @doc """
  How many characters `text` has, without its Markdown, measured against
  `limit`: the sentence to show, and whether it's over.

  `max` is the most the field holds, counting its Markdown (its
  attribute's `max_length`), or `nil`. Past it, the field won't save, and
  the sentence says so.
  """
  @spec count(String.t() | nil, pos_integer(), pos_integer() | nil) :: %{
          text: String.t(),
          over: boolean()
        }
  def count(text, limit, max \\ nil) do
    text = String.trim(to_string(text))
    stored = String.length(text)
    length = String.length(Markdown.plain(text))

    cond do
      is_integer(max) and stored > max ->
        %{
          text:
            "Too long to save: #{stored} characters, over #{max}.#{markdown_note(stored, length)}",
          over: true
        }

      length > limit ->
        %{
          text: "#{length} characters, over #{limit}. It still saves, but it may crowd the page.",
          over: true
        }

      true ->
        %{text: "#{length} of #{limit} characters", over: false}
    end
  end

  defp markdown_note(length, length), do: ""
  defp markdown_note(_stored, _length), do: " Its Markdown counts toward this."

  @doc """
  A layout's name: in full, or `:short`, as the controls header says it
  ("Photo left").
  """
  def variant_label(variant, length \\ :full)
  def variant_label(variant, :full), do: Map.fetch!(@variant_labels, variant)

  def variant_label(variant, :short),
    do: Map.get(@short_variant_labels, variant, variant_label(variant))

  @doc """
  What a button that adds one of `spec`'s parts says: "Add a point", "Add
  an action".
  """
  def add_words(spec) do
    item = spec[:item_label] || "item"
    "Add #{article(item)} #{item}"
  end

  defp article(<<first, _rest::binary>>) when first in ~c"aeiou", do: "an"
  defp article(_word), do: "a"
end
