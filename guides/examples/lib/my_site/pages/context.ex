defmodule MySite.Pages.Context do
  @moduledoc """
  What the site's pages are about: a service's page is about that
  service, whose name stands in for its hero's heading, and whose fees
  a Fees section may show alone.
  """
  @behaviour Billboard.Context

  @services [
    {"Assessments", "assessments"},
    {"Therapy", "therapy"},
    {"Supervision", "supervision"}
  ]

  @impl true
  def bindings,
    do: [
      service: [
        note: "The heading comes from the service.",
        link: {"Open the services", "/admin/services"},
        replaces_words: true
      ]
    ]

  @impl true
  def choice_sets, do: [:services]

  @impl true
  def choices(:services),
    do: %{
      options: @services,
      every: "Every service",
      none_yet: "There are no services yet.",
      gone: "not a service now"
    }

  # The editor draws a service's page about the first service.
  @impl true
  def sample(%{pattern: "/services/:slug"}),
    do: %{bindings: %{service: %{heading: "Assessments"}}, scope: "assessments"}

  def sample(_page), do: %{}

  @impl true
  def path(%{pattern: nil}, _context), do: nil
  def path(%{pattern: "/services/:slug"}, %{scope: scope}), do: "/services/#{scope}"
  def path(%{pattern: "/services/:slug"}, _context), do: nil
  def path(%{pattern: pattern}, _context), do: pattern
end
