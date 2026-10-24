defmodule Billboard.Component.Verifiers.VerifyEditor do
  @moduledoc """
  Checks the `editor` section: each entry edits one of the component's
  attributes, but a note, which edits nothing, and no two edit the same
  one; `hide_when` names attributes; words edit a string; a part edits a
  part, and a list a list of parts, each naming its part, by a stock
  part's name or a site's part (`Billboard.Part`); a choice names
  its set; several choices edit a list of strings, and there's at most
  one set of them (`:choices`), since the editor keeps one a section, in
  the order it was ticked; a select's options and the variants' layouts
  are given, and are among the attribute's `one_of` values when it has
  them; and a select's `only_on` names its options. A part or list
  naming a site's part by its module edits an attribute of that part,
  and a component's `:action` or `:actions`, which billboard reads as
  the section's actions (`Billboard.Rules.actions_of/1`), holds
  `:action` or `:link` parts.

  It checks a site's part's `editor` too (`Billboard.Part`), whose
  fixes are worded for a part, which holds its own parts in attributes.
  Each message names the fix, and a misspelt name is met with the
  attribute it most likely meant. Its errors are compile warnings, as
  every Spark verifier's are.
  """
  use Spark.Dsl.Verifier

  alias Billboard.Component.{Field, Words}
  alias Spark.Dsl.Verifier

  @notes [:note, :binding_note]

  # What billboard reads as a section's actions, by its attribute's name.
  @actions [:action, :actions]

  @impl true
  def verify(dsl_state) do
    module = Verifier.get_persisted(dsl_state, :module)
    attributes = Map.new(Ash.Resource.Info.attributes(dsl_state), &{&1.name, &1})
    entries = Verifier.get_entities(dsl_state, [:editor])
    # A site's part has no `component` section, so a fix names its own
    # attributes instead.
    owner = if site_part?(dsl_state), do: :part, else: :component

    messages =
      for(
        {entry, earlier} <- Enum.zip(entries, earlier_names(entries)),
        message <- problems(entry, attributes, module, owner) ++ twice(entry, earlier),
        do: {entry, message}
      ) ++ second_choices(entries)

    errors =
      for {entry, message} <- messages do
        Spark.Error.DslError.exception(
          module: module,
          path: [:editor, entry.name],
          location: Spark.Dsl.Entity.anno(entry),
          message: message
        )
      end

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp site_part?(dsl_state),
    do: Billboard.Part.Dsl in (Verifier.get_persisted(dsl_state, :spark_extensions) || [])

  # The names of the entries before each one.
  defp earlier_names(entries) do
    entries
    |> Enum.map(& &1.name)
    |> Enum.scan([], &[&1 | &2])
    |> then(&[[] | Enum.drop(&1, -1)])
  end

  # Spark keeps a name unique only among one kind of entry, so a `words`
  # and a `field` could edit the same attribute.
  defp twice(entry, earlier) do
    if entry.name in earlier,
      do: [
        "`#{inspect(entry.name)}` is in `editor` twice. Give each entry an attribute of its " <>
          "own, or take one out"
      ],
      else: []
  end

  # The editor keeps one set of several choices a section, in the order
  # it was ticked, and draws it under one id, so a second is refused.
  defp second_choices(entries) do
    for %Field{as: :choices, name: name} = entry <- Enum.drop(choices(entries), 1),
        do:
          {entry,
           "`#{inspect(name)}` is a second set of several choices in `editor`, and the editor " <>
             "offers one a section. Make it a `:choice`, or take it out of `editor`"}
  end

  defp choices(entries), do: Enum.filter(entries, &match?(%Field{as: :choices}, &1))

  defp problems(%Field{as: as} = entry, attributes, module, _owner) when as in @notes,
    do: hide_when(entry, attributes, module)

  defp problems(entry, attributes, module, owner) do
    name = entry.name

    case Map.fetch(attributes, name) do
      :error ->
        [
          "`#{inspect(name)}` is in `editor` but isn't an attribute of #{inspect(module)}" <>
            "#{did_you_mean(name, attributes)}. Add #{needs(entry, owner)}, or take it out of `editor`"
        ]

      {:ok, attribute} ->
        hide_when(entry, attributes, module) ++
          words(entry, attribute) ++
          part(entry) ++
          part_attribute(entry, attribute, owner) ++
          actions(entry, owner) ++
          from(entry) ++
          options(entry) ++
          one_of(entry, attribute) ++
          only_on(entry) ++
          choices_attribute(entry, attribute)
    end
  end

  # What an entry needs, by what it is, for a message that names the fix:
  # a component holds a part by its `component` section, and a site's
  # part by an attribute.
  defp needs(%Field{as: :part, name: name}, :component),
    do: "`part #{inspect(name)}, MySite.Parts.Name` to `component`"

  defp needs(%Field{as: :list, name: name}, :component),
    do: "`parts #{inspect(name)}, MySite.Parts.Name` to `component`"

  defp needs(%Field{as: :photo, name: name}, :component),
    do: "`part #{inspect(name)}, MySite.Parts.Photo` to `component`"

  defp needs(%Field{as: as, name: name}, :part) when as in [:part, :list, :photo],
    do: "`#{held(as, name)}` to its `attributes`"

  defp needs(entry, _owner), do: needs(entry)

  defp needs(%Field{as: :choices, name: name}),
    do: "`attribute #{inspect(name)}, {:array, :string}`"

  defp needs(%Field{as: :toggle, name: name}), do: "`attribute #{inspect(name)}, :boolean`"
  defp needs(%Field{as: :number, name: name}), do: "`attribute #{inspect(name)}, :integer`"

  defp needs(%Field{as: as, name: name} = entry) when as in [:select, :variants] do
    values =
      case option_values(entry) do
        [] -> "[…]"
        values -> inspect(values)
      end

    "`attribute #{inspect(name)}, :atom, constraints: [one_of: #{values}]`"
  end

  defp needs(entry), do: "`attribute #{inspect(entry.name)}, :string`"

  # The attribute a misspelt name most likely meant, if one is close.
  defp did_you_mean(name, attributes) do
    candidates = attributes |> Map.keys() |> List.delete(:component)

    best =
      Enum.max_by(
        candidates,
        &String.jaro_distance(to_string(&1), to_string(name)),
        fn -> nil end
      )

    if best && String.jaro_distance(to_string(best), to_string(name)) >= 0.85,
      do: " (did you mean `#{inspect(best)}`?)",
      else: ""
  end

  defp hide_when(entry, attributes, module) do
    for {field, _values} <- entry.hide_when || [],
        not Map.has_key?(attributes, field),
        do:
          "`#{inspect(entry.name)}` hides when `#{inspect(field)}` holds some values, but " <>
            "`#{inspect(field)}` isn't an attribute of #{inspect(module)}" <>
            "#{did_you_mean(field, attributes)}. Name one of its attributes in `hide_when`, " <>
            "or take it out"
  end

  defp words(%Words{name: name}, %{type: type}) when type != Ash.Type.String,
    do: [
      "`#{inspect(name)}` is words in `editor`, but it isn't a string. Make it a `field`, " <>
        "or `#{inspect(name)}` a string attribute"
    ]

  defp words(_entry, _attribute), do: []

  defp part(%Field{as: as, part: nil, name: name}) when as in [:part, :list],
    do: [
      "`#{inspect(name)}` is a #{as} in `editor` but names no part. Add `part: :detail`, " <>
        "or the part it holds (`Billboard.Sections.Parts.editor_fields/1`)"
    ]

  # A part named by its module must be a site's part, whose editor fields
  # and blank the editor reads; any other module has neither.
  defp part(%Field{as: as, part: part, name: name})
       when as in [:part, :list] and is_atom(part) do
    cond do
      part in Billboard.Sections.Parts.parts() ->
        []

      match?({:module, _}, Code.ensure_compiled(part)) and Billboard.Part.Info.part?(part) ->
        []

      true ->
        [
          "`#{inspect(name)}` is a #{as} in `editor` whose part, #{inspect(part)}, isn't one " <>
            "the editor knows. Name it by its stock name, as `part: :detail`, or give " <>
            "#{inspect(part)} `use Billboard.Part`"
        ]
    end
  end

  defp part(_entry), do: []

  defp part_attribute(%Field{as: :part, name: name} = entry, %{type: type}, owner) do
    cond do
      not part?(type) ->
        [
          "`#{inspect(name)}` is a part in `editor`, but it isn't a part. " <>
            "#{in_place(:part, name, owner)}, or make it another kind of entry"
        ]

      named_module?(entry) and entry.part != type ->
        [held_other(entry, type)]

      true ->
        []
    end
  end

  defp part_attribute(%Field{as: :list, name: name} = entry, %{type: type}, owner) do
    cond do
      not (match?({:array, item} when is_atom(item), type) and part?(elem(type, 1))) ->
        [
          "`#{inspect(name)}` is a list in `editor`, but it isn't a list of parts. " <>
            "#{in_place(:list, name, owner)}, or make it another kind of entry"
        ]

      named_module?(entry) and entry.part != elem(type, 1) ->
        [held_other(entry, elem(type, 1))]

      true ->
        []
    end
  end

  defp part_attribute(_entry, _attribute, _owner), do: []

  defp in_place(as, name, :component),
    do:
      "Add `#{if as == :list, do: "parts", else: "part"} #{inspect(name)}, MySite.Parts.Name` " <>
        "to `component` in place of its attribute"

  defp in_place(as, name, :part), do: "Make its attribute `#{held(as, name)}`"

  defp held(:list, name),
    do: "attribute #{inspect(name)}, {:array, MySite.Parts.Name}, public?: true"

  defp held(:photo, name), do: "attribute #{inspect(name)}, Billboard.Parts.Photo, public?: true"
  defp held(_as, name), do: "attribute #{inspect(name)}, MySite.Parts.Name, public?: true"

  # A part named by its module, not by a stock part's name.
  defp named_module?(%Field{part: part}),
    do: is_atom(part) and not is_nil(part) and part not in Billboard.Sections.Parts.parts()

  # The editor reads a site's part's fields and blank from the module
  # `part:` names, so it must be the one the attribute holds.
  defp held_other(%Field{as: as, name: name, part: part}, held) do
    "`#{inspect(name)}` is a #{as} of #{inspect(part)} in `editor`, but its attribute holds " <>
      "#{inspect(held)}. Name the part it holds, as `part: #{inspect(held)}`, or make the " <>
      "attribute hold #{inspect(part)}"
  end

  # Billboard reads a section's `:action` and `:actions` as its actions,
  # by their kind and style (`Billboard.Rules.actions_of/1`), so they must
  # hold billboard's action part.
  defp actions(%Field{as: as, name: name, part: part}, :component)
       when as in [:part, :list] and name in @actions and part not in [nil, :action, :link] do
    [
      "`#{inspect(name)}` is a #{as} of #{inspect(part)} in `editor`, but billboard reads a " <>
        "section's `#{inspect(name)}` as its actions (`Billboard.Parts.Action`). Make it " <>
        "`part: :action`, or give the attribute another name"
    ]
  end

  defp actions(_entry, _owner), do: []

  # A part is an Ash resource; `Billboard.Component.Verifiers.VerifyParts`
  # checks the rest of what it must be.
  defp part?(type) when is_atom(type) do
    match?({:module, _}, Code.ensure_compiled(type)) and Spark.Dsl.is?(type, Ash.Resource)
  end

  defp part?(_type), do: false

  defp from(%Field{as: as, from: nil, name: name}) when as in [:choice, :choices],
    do: [
      "`#{inspect(name)}` is a choice in `editor` but names no set. Add `from: :scope`, " <>
        "or the set it picks from (`Billboard.Context.choices/1`)"
    ]

  defp from(_entry), do: []

  defp options(%Field{as: :select, options: options, name: name}) when options in [nil, []],
    do: [
      ~s|`#{inspect(name)}` is a select in `editor` but gives no options. | <>
        ~s|Add `options: [{"Label", :value}, …]`|
    ]

  defp options(%Field{as: :variants, options: options, name: name}) when options in [nil, []],
    do: [
      "`#{inspect(name)}` is variants in `editor` but gives no layouts. " <>
        "Add `options: [:text_only, :media_right, …]`, its layouts in order"
    ]

  defp options(_entry), do: []

  # A select's or the variants' values must be ones the attribute takes,
  # or choosing one would be refused when the section is saved.
  defp one_of(%Field{as: as, name: name} = entry, %{constraints: constraints})
       when as in [:select, :variants] do
    allowed = constraints[:one_of]
    outside = if allowed, do: Enum.uniq(option_values(entry) -- allowed), else: []

    case outside do
      [] ->
        []

      [one] ->
        [
          "`#{inspect(name)}` offers `#{inspect(one)}` in `editor`, which isn't among its " <>
            "values (`one_of: #{inspect(allowed)}`). Add it to its `one_of`, or take it out " <>
            "of `options`"
        ]

      several ->
        [
          "`#{inspect(name)}` offers #{in_words(several)} in `editor`, which aren't among " <>
            "its values (`one_of: #{inspect(allowed)}`). Add them to its `one_of`, or take " <>
            "them out of `options`"
        ]
    end
  end

  defp one_of(_entry, _attribute), do: []

  # `only_on` keeps some of a select's options to some page kinds, so each
  # value it names must be one of them, or the editor would keep nothing.
  defp only_on(%Field{as: :select, only_on: [_ | _] = only_on, name: name} = entry) do
    case Enum.uniq(Keyword.keys(only_on) -- option_values(entry)) do
      [] ->
        []

      [one] ->
        [
          "`#{inspect(name)}` keeps `#{inspect(one)}` to some page kinds in `only_on`, but " <>
            "offers no such option. Add it to `options`, or take it out of `only_on`"
        ]

      several ->
        [
          "`#{inspect(name)}` keeps #{in_words(several)} to some page kinds in `only_on`, " <>
            "but offers no such options. Add them to `options`, or take them out of `only_on`"
        ]
    end
  end

  defp only_on(_entry), do: []

  defp option_values(%Field{as: :select, options: options}) when is_list(options),
    do: for({_label, value} <- options, do: value)

  defp option_values(%Field{as: :variants, options: options}) when is_list(options),
    do: options

  defp option_values(_entry), do: []

  defp choices_attribute(%Field{as: :choices, name: name}, %{type: type})
       when type != {:array, Ash.Type.String},
       do: [
         "`#{inspect(name)}` is several choices in `editor`, but it isn't a list of strings. " <>
           "Make it `attribute #{inspect(name)}, {:array, :string}`"
       ]

  defp choices_attribute(_entry, _attribute), do: []

  defp in_words(values) do
    quoted = Enum.map(values, &"`#{inspect(&1)}`")

    case quoted do
      [a, b] -> "#{a} and #{b}"
      _ -> Enum.join(Enum.drop(quoted, -1), ", ") <> ", and " <> List.last(quoted)
    end
  end
end
