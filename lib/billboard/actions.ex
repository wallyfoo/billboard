defmodule Billboard.Actions do
  @moduledoc """
  The kinds of action a site's buttons and links may take. An action
  (`Billboard.Parts.Action`) goes to a page on the site (`:link`), or
  does something of the site's own, such as booking or ringing, which
  the site lists and draws. A site names its module in
  `use Billboard.Site`, as `actions: MySiteWeb.Actions`:

      defmodule MySiteWeb.Actions do
        @behaviour Billboard.Actions
        use Phoenix.Component

        import Billboard.Sections.Buttons

        @impl true
        def kinds, do: [call: [label: "Call us", words: :site]]

        @impl true
        def action(%{action: %{kind: :call}} = assigns) do
          ~H\"\"\"
          <.bb_button href={"tel:" <> @ctx.site.phone}>Call {@ctx.site.phone}</.bb_button>
          \"\"\"
        end
      end

  `kinds/0` lists them in the order the editor's "Goes to" offers them,
  each with:

    * `label`, the editor's words for it;
    * `words: :site` when the site words the button itself, so the
      editor hides its words and says so, or `:own`, the default, when
      the admin writes them;
    * `only_on`, the page kinds it goes on, when it doesn't go on every
      kind.

  `:link` is billboard's. List it, as `link: []`, to place it among the
  site's; leave it out and it comes first. `action/1` draws every other
  kind, given `action`, `ctx`, and `prefix`, the prefix of the ids its
  section's actions take (`Billboard.Sections.Parts.action/1`). The
  optional `label_hint/0` is the hint under a button's words.

  A site with no actions module has links alone. An action saved with a
  kind the site no longer lists keeps it until someone changes it, and
  draws nothing meanwhile.
  """

  @typedoc "One kind's options, as `kinds/0` gives them."
  @type kind :: [label: String.t(), words: :own | :site, only_on: [atom()]]

  @doc "The site's kinds, in the editor's order. See the moduledoc."
  @callback kinds() :: keyword(kind())

  @doc "Draws an action of one of the site's kinds."
  @callback action(map()) :: Phoenix.LiveView.Rendered.t()

  @doc "The hint under a button's words."
  @callback label_hint() :: String.t()

  @optional_callbacks label_hint: 0

  @link [label: "A page on this site", words: :own]

  @doc """
  Every kind the site offers, `:link` among them, in the editor's order,
  each with its options: `words` is `:own` unless the site says
  otherwise, and the link is "A page on this site".
  """
  @spec kinds() :: keyword(kind())
  def kinds do
    site = if module = Billboard.Site.actions(), do: module.kinds(), else: []
    kinds = if Keyword.has_key?(site, :link), do: site, else: [{:link, []} | site]

    for {kind, opts} <- kinds do
      defaults = if kind == :link, do: @link, else: [words: :own]
      {kind, Keyword.merge(defaults, opts)}
    end
  end

  @doc "Whether the site offers the kind `kind` (an atom)."
  @spec offered?(atom()) :: boolean()
  def offered?(kind), do: Keyword.has_key?(kinds(), kind)

  @doc "The site's hint under a button's words, or nil."
  @spec label_hint() :: String.t() | nil
  def label_hint do
    module = Billboard.Site.actions()

    if module && Code.ensure_loaded?(module) && function_exported?(module, :label_hint, 0),
      do: module.label_hint()
  end
end
