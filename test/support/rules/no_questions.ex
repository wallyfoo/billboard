defmodule Billboard.Test.NoQuestions do
  @moduledoc "A component's own rule: questions with no answers yet are a warning."
  @behaviour Billboard.Component.Rule

  import Billboard.Rule, only: [warning: 2]

  @impl true
  def check(section, _page, _shared) do
    if Enum.any?(section.content.value.questions, &is_nil(&1.answer)),
      do: [warning(section, "a question has no answer yet")],
      else: []
  end
end
