defmodule Billboard.Test.SignIn do
  @moduledoc """
  The test site's sign-in, as a site's `require_authenticated` hook is: a
  session marked `"signed_in"` (`Billboard.Test.LiveCase.signed_in/1`)
  gets the shop's admin as its `current_scope`, and any other is sent to
  `"/"`.
  """
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:admin, _params, session, socket) do
    if session["signed_in"] do
      {:cont, assign(socket, :current_scope, %{user: Billboard.Test.Fixtures.admin()})}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end
end
