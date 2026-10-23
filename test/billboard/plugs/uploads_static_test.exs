defmodule Billboard.Plugs.UploadsStaticTest do
  @moduledoc "Photographs are served from the uploads directory, as plain files."
  use ExUnit.Case, async: false

  import Plug.Test

  alias Billboard.Plugs.UploadsStatic

  setup do
    File.mkdir_p!(Billboard.Uploads.dir())
    path = Path.join(Billboard.Uploads.dir(), "probe.png")
    File.write!(path, "not really a png")
    on_exit(fn -> File.rm(path) end)
  end

  test "serves /uploads/NAME from the directory, never sniffed" do
    conn = :get |> conn("/uploads/probe.png") |> UploadsStatic.call(UploadsStatic.init([]))

    assert conn.status == 200
    assert conn.resp_body == "not really a png"
    assert Plug.Conn.get_resp_header(conn, "x-content-type-options") == ["nosniff"]
  end

  test "leaves every other path alone" do
    conn = :get |> conn("/shop") |> UploadsStatic.call(UploadsStatic.init([]))
    refute conn.halted
    assert conn.status == nil
  end
end
