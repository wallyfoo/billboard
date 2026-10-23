defmodule Billboard.Component.Rule do
  @moduledoc """
  A component's own rule: a problem with one of its sections, as an
  error that holds Publish back or a warning that doesn't
  (`Billboard.Rule.error/2` and `warning/2`). A component lists its rules
  in its `component` section, `rules [MySite.Rules.UnansweredQuestions]`,
  and `Billboard.Rules.check/3` runs them on each of its sections, those
  in columns included, after the stock rules and before the site's.

      defmodule MySite.Rules.UnansweredQuestions do
        @behaviour Billboard.Component.Rule

        import Billboard.Rule, only: [warning: 2]

        @impl true
        def check(section, _page, _shared) do
          if Enum.any?(section.content.value.questions, &is_nil(&1.answer)),
            do: [warning(section, "a question has no answer yet")],
            else: []
        end
      end

  `page` is the page's directory entry (`Billboard.Directory.Page`), and
  `shared` the library's sections by key, as `Billboard.Rules.check/3`
  takes them. A rule about the whole page, or about several components,
  is the site's own (`Billboard.Rule`).
  """

  @doc "The issues `section`, one of the component's, has on `page`."
  @callback check(section :: map(), page :: Billboard.Directory.Page.t(), shared :: map()) ::
              [Billboard.Rule.issue()]
end
