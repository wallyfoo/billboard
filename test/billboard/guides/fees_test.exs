defmodule Billboard.Guides.FeesTest do
  @moduledoc """
  The page kinds guide's Fees: the component works, draws only the page's
  service's fees when limited, and its site's data and context answer as
  the guide says.
  """
  use Billboard.ComponentCase,
    endpoint: Billboard.Test.Endpoint,
    repo: Billboard.Test.Repo,
    async: false

  import Billboard.Test.Render

  alias MySite.Pages

  @fees MySite.Fees.list()

  defp drawn(only) do
    section = section(:fees, %{title: "Fees", only_service: only})
    visitor(section, %{data: %{"s1" => @fees}, context: %{scope: "assessments"}})
  end

  test "works, with the fees the site's data gives" do
    assert_component_works(MySite.Sections.Fees, data: @fees, context: %{scope: "assessments"})
  end

  test "draws every fee, or only the page's service's when limited" do
    every = drawn(nil)
    assert every =~ "A first assessment"
    assert every =~ "A session"

    limited = drawn("assessments")
    assert limited =~ "A first assessment"
    assert limited =~ "A follow-up"
    refute limited =~ "A session"
  end

  test "the site's data reads the fees once for two sections" do
    fees = Billboard.Component.build!(:fees, %{title: "Fees"})

    assert {:ok, @fees, loaded} = Pages.Data.fetch(fees, %{}, %{})
    assert {:ok, @fees, ^loaded} = Pages.Data.fetch(fees, %{}, loaded)

    assert Pages.Data.fetch(Billboard.Component.build!(:band, %{heading: "Visit"}), %{}, loaded) ==
             :none
  end

  test "the editor draws a service's page about the first service, at its address" do
    page = %{pattern: "/services/:slug"}
    sample = Pages.Context.sample(page)

    assert %{bindings: %{service: %{heading: "Assessments"}}, scope: "assessments"} = sample
    assert Pages.Context.path(page, sample) == "/services/assessments"
    assert Pages.Context.path(%{pattern: nil}, %{}) == nil
    assert Pages.Context.path(%{pattern: "/about"}, %{}) == "/about"
  end

  test "gives the services as a set of choices, in the shape a picker reads" do
    assert Pages.Context.choice_sets() == [:services]

    assert %{options: [{"Assessments", "assessments"} | _], every: _, none_yet: _, gone: _} =
             Pages.Context.choices(:services)
  end
end
