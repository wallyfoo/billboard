defmodule MySite.Sections.Faq.UnansweredQuestions do
  @moduledoc """
  A question with no answer yet is a warning: the editor marks the
  section and says so, and Publish still works.
  """
  @behaviour Billboard.Component.Rule

  import Billboard.Rule, only: [warning: 2]

  @impl true
  def check(section, _page, _shared) do
    case Enum.count(section.content.value.questions, &unanswered?/1) do
      0 -> []
      1 -> [warning(section, "a question has no answer yet")]
      count -> [warning(section, "#{count} questions have no answer yet")]
    end
  end

  defp unanswered?(question), do: is_nil(question.body) or String.trim(question.body) == ""
end
