defmodule Billboard.Plugs.UploadsStatic do
  @moduledoc """
  Serves `/uploads` from the runtime-configured uploads directory, which
  `Plug.Static` alone cannot do because it resolves `:from` at compile time.

  A site plugs it into its endpoint, before `Plug.Static`:
  `plug Billboard.Plugs.UploadsStatic`.
  """
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{path_info: ["uploads" | _]} = conn, _opts) do
    opts = Plug.Static.init(at: "/uploads", from: Billboard.Uploads.dir(), gzip: false)

    conn
    |> Plug.Conn.put_resp_header("x-content-type-options", "nosniff")
    |> Plug.Static.call(opts)
  end

  def call(conn, _opts), do: conn
end
