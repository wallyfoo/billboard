defmodule Billboard.Test.Endpoint do
  @moduledoc "The test site's endpoint, for the editor's LiveView tests."
  use Phoenix.Endpoint, otp_app: :billboard

  @session [store: :cookie, key: "_billboard_test", signing_salt: "billboard-test"]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session]]

  plug Plug.Session, @session
  plug Billboard.Test.Router
end
