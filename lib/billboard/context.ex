defmodule Billboard.Context do
  @moduledoc """
  What a site's pages are about, for sections that draw more than their
  own content. A site names its module in `use Billboard.Site`, as
  `context: MySite.Pages.Context`.

  A page's context, `ctx.context`, is a map the site builds for each page
  it draws, as its LiveViews see fit. The stock components read two of
  its entries, and say so in their `context` (`Billboard.Component`):

    * `:bindings`, what a bound hero draws, by binding: any of
      `:heading` (plain text), `:eyebrow`, `:lede` (Markdown),
      `:photo_label`, and `:seed`, the pattern of the photograph's
      placeholder. A key the binding leaves out leaves the hero's own
      words in its place, and a binding the page hasn't got leaves them
      throughout.
    * `:scope`, what a detail limited to one place (its
      `only_for_group`) shows on: such a detail shows only where the
      page's scope is the same.

  The site's own components may read any entry. The module answers,
  each optionally:

    * `bindings/0`, the bindings a hero may take, in order, each with
      `note` and `link`, what the editor says about it and where its
      words are changed, as `{words, path}`, and `replaces_words: true`
      when its words stand in for the hero's own, which the editor then
      hides. A hero saved with a binding the site no longer lists keeps
      it, and draws its own words.
    * `choice_sets/0`, the names of the sets of choices it gives, such
      as `[:scope]`. Billboard asks `choices/1` for these alone, so a
      picker of a set the site doesn't give draws nothing rather than
      failing.
    * `choices/1`, the set of choices called `name`, one of
      `choice_sets/0`: `%{options: [{label, value}], every: words, none_yet: words, gone: words}`,
      its options, then the words for none chosen (every one), for none
      to choose from yet, and for a value that has gone, as in
      "shoes (not an aisle now)". Billboard's own picker is `:scope`, a
      detail's "Shows on".

  A module that gives `choices/1` gives `choice_sets/0` too, which
  `use Billboard.Site` checks:

      defmodule MySite.Pages.Context do
        @behaviour Billboard.Context

        @sets [:scope]

        @impl true
        def choice_sets, do: @sets

        @impl true
        def choices(:scope),
          do: %{
            options: [{"Shoes", "shoes"}, {"Hats", "hats"}],
            every: "Every aisle",
            none_yet: "There are no aisles yet.",
            gone: "not an aisle now"
          }
      end
  """

  @typedoc "A set of choices. See the moduledoc."
  @type choices :: %{
          options: [{String.t(), String.t()}],
          every: String.t(),
          none_yet: String.t(),
          gone: String.t()
        }

  @doc "The bindings a hero may take. See the moduledoc."
  @callback bindings() :: keyword(keyword())

  @doc "The names of the sets of choices the site gives, each one `choices/1` answers."
  @callback choice_sets() :: [atom()]

  @doc "The set of choices called `name`, one of `choice_sets/0`. See the moduledoc."
  @callback choices(atom()) :: choices()

  @optional_callbacks bindings: 0, choice_sets: 0, choices: 1

  @doc "The bindings a hero may take, or none for a site that names none."
  @spec bindings() :: keyword(keyword())
  def bindings, do: call(:bindings, [], [])

  @doc """
  The binding `bind` names, an atom or a form's string, as
  `{name, options}`, or nil for `:none` and for one the site doesn't list.
  """
  @spec binding_for(atom() | String.t() | nil) :: {atom(), keyword()} | nil
  def binding_for(bind),
    do: Enum.find(bindings(), fn {name, _opts} -> to_string(name) == to_string(bind) end)

  @doc "Whether a hero bound to `bind` draws the binding's words in place of its own."
  @spec replaces_words?(atom() | String.t() | nil) :: boolean()
  def replaces_words?(bind) do
    case binding_for(bind) do
      {_name, opts} -> Keyword.get(opts, :replaces_words, false)
      nil -> false
    end
  end

  @doc "The names of the sets of choices the site gives, or none for a site that gives none."
  @spec choice_sets() :: [atom()]
  def choice_sets, do: call(:choice_sets, [], [])

  @doc """
  The set of choices called `name`. Raises, naming the fix, for one the
  site doesn't give (`choice_sets/0`).
  """
  @spec choices(atom()) :: choices()
  def choices(name) do
    (name in choice_sets() && call(:choices, [name], nil)) ||
      raise ArgumentError,
            "the site offers no choices called #{inspect(name)}. List #{inspect(name)} in the " <>
              "choice_sets/0 of its `context:` module (`Billboard.Context`), and give it a " <>
              "`choices(#{inspect(name)})` clause"
  end

  @doc """
  The sets of choices `names` names that the site gives, by name, as the
  editor reads them once. A set the site doesn't give is left out, and a
  picker of it draws nothing.
  """
  @spec choices_for([atom()]) :: %{atom() => choices()}
  def choices_for(names) do
    sets = choice_sets()
    for name <- names, name in sets, into: %{}, do: {name, choices(name)}
  end

  defp call(name, args, default) do
    module = Billboard.Site.context()

    if module && Code.ensure_loaded?(module) && function_exported?(module, name, length(args)),
      do: apply(module, name, args),
      else: default
  end
end
