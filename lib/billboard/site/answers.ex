defmodule Billboard.Site.Answers do
  @moduledoc false
  # The schema of `use Billboard.Site`'s answers, checked as the site
  # module compiles, and the rules by which a test's env overrides them.
  # `Billboard.Site` documents both.

  @no_reserved_ids [ids: [], prefixes: [], suffixes: [], owned: %{}]

  @schema [
    repo: [type: :atom],
    pubsub: [type: :atom],
    domain: [type: :atom],
    resources: [
      type: :keyword_list,
      default: [],
      keys: [
        page: [type: :atom],
        version: [type: :atom],
        section: [type: :atom],
        content: [type: :atom]
      ]
    ],
    components: [type: {:list, :atom}, default: []],
    surfaces: [type: {:list, {:custom, __MODULE__, :check_surface, []}}, default: []],
    offered: [type: {:custom, __MODULE__, :check_offered, []}, default: []],
    options: [type: {:custom, __MODULE__, :check_options, []}, default: []],
    rules: [type: {:list, :atom}, default: []],
    starter: [type: :atom],
    reserved_ids: [
      type: :keyword_list,
      default: @no_reserved_ids,
      keys: [
        ids: [type: {:list, :string}, default: []],
        prefixes: [type: {:list, :string}, default: []],
        suffixes: [type: {:list, :string}, default: []],
        owned: [type: {:map, :string, :atom}, default: %{}]
      ]
    ]
  ]

  @doc false
  def validate!(answers, module) do
    case Spark.Options.validate(answers, @schema) do
      {:ok, answers} ->
        answers

      {:error, error} ->
        raise ArgumentError,
              "#{inspect(module)}'s `use Billboard.Site`: #{Exception.message(error)}"
    end
  end

  @doc false
  def no_reserved_ids, do: @no_reserved_ids

  @doc false
  def check_surface(%{name: name, label: label} = surface)
      when is_binary(name) and is_binary(label) and map_size(surface) == 2,
      do: {:ok, surface}

  def check_surface(other) do
    {:error,
     "each surface is a map of a string name and label, such as " <>
       "`%{name: \"paper\", label: \"Paper\"}`, not #{inspect(other)}"}
  end

  @doc false
  def check_offered(offered) do
    if Keyword.keyword?(offered) and
         Enum.all?(offered, fn {_kind, names} ->
           is_list(names) and Enum.all?(names, &is_binary/1)
         end),
       do: {:ok, offered},
       else:
         {:error,
          "offered gives each kind its surfaces' names, such as " <>
            "`[page: [\"paper\"], stand_out: [\"band\"]]`, not #{inspect(offered)}"}
  end

  @doc false
  def check_options(options) do
    if Keyword.keyword?(options) and
         Enum.all?(options, fn {_type, fields} -> Keyword.keyword?(fields) end),
       do: {:ok, options},
       else:
         {:error,
          "options gives each component type its fields' offers, such as " <>
            "`[points: [look: [:rows], points: 1..3]]`, not #{inspect(options)}"}
  end

  @doc false
  def surfaces(answers, env), do: Keyword.get(env, :surfaces, answers[:surfaces])

  @doc false
  def offered(answers, env) do
    if Keyword.has_key?(env, :surfaces),
      do: Keyword.get(env, :offered, []),
      else: Keyword.merge(answers[:offered], Keyword.get(env, :offered, []))
  end

  @doc false
  def options(answers, env) do
    Keyword.merge(answers[:options], Keyword.get(env, :options, []), fn _type, ours, theirs ->
      Keyword.merge(ours, theirs)
    end)
  end

  @doc false
  def rules(answers, env), do: Keyword.get(env, :rules, answers[:rules])
end
