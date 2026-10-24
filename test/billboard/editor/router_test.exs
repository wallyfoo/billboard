defmodule Billboard.Editor.RouterTest do
  @moduledoc "The editor, mounted in a site's router, and the addresses it's reached at."
  use Billboard.Test.LiveCase, async: false

  alias Billboard.Editor
  alias Billboard.Test.Router

  defmodule NoEditor do
    @moduledoc "A site's router that doesn't mount the editor."
    use Phoenix.Router
  end

  setup :preserve_cache

  test "is reached at its route's address, its query encoded" do
    # In the order `~p` gave it, its keys sorted.
    assert Editor.path(Router, "/items/:slug", open: "hero") ==
             "/pages?open=hero&page=%2Fitems%2F%3Aslug"

    assert Editor.path(Router, "/") == "/pages?page=%2F"
    assert Editor.path(Router, nil) == "/pages?page=shared"
    assert Editor.path(Router, nil, open: "promo") == "/pages?open=promo&page=shared"
  end

  test "carries its back link in its route" do
    assert Editor.mount(Router) == %{path: "/pages", back: {"Admin", "/admin"}}
  end

  test "says how to mount it when the router doesn't" do
    assert_raise ArgumentError, ~r/doesn't mount the page editor. Add `billboard_editor/, fn ->
      Editor.mount(NoEditor)
    end
  end

  test "draws in a container of its own, marked for its stylesheet" do
    html = signed_in(build_conn()) |> get("/pages") |> html_response(200)

    assert [_container] =
             html
             |> LazyHTML.from_document()
             |> LazyHTML.query("div.bb-editor[data-phx-main]")
             |> Enum.to_list()
  end

  test "a visitor is sent away by the session's on_mount" do
    assert {:error, {:redirect, %{to: "/"}}} = live(build_conn(), "/pages")
  end

  test "a LiveView mounted without a signed-in user says how to mount it" do
    assert_raise ArgumentError, ~r/needs `@current_scope`.*`billboard_editor`/s, fn ->
      live_isolated(build_conn(), Billboard.EditorLive)
    end
  end
end
