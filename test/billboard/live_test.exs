defmodule Billboard.LiveTest do
  @moduledoc "LiveViews run against the test endpoint, signed in or not."
  use Billboard.Test.LiveCase, async: false

  test "a signed-in admin's scope reaches the LiveView" do
    {:ok, view, _html} = live(signed_in(build_conn()), "/probe")
    assert has_element?(view, "#probe-user", "admin")
  end

  test "a visitor who isn't signed in is sent away" do
    assert {:error, {:redirect, %{to: "/"}}} = live(build_conn(), "/probe")
  end
end
