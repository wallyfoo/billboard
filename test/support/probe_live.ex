defmodule Billboard.Test.ProbeLive do
  @moduledoc "A LiveView that shows who it's signed in as, for testing the test site itself."
  use Phoenix.LiveView

  @impl true
  def render(assigns) do
    ~H"""
    <p id="probe-user">{@current_scope.user.id}</p>
    """
  end
end
