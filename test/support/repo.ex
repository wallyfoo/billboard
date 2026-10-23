defmodule Billboard.Test.Repo do
  @moduledoc """
  The test site's repo, set up as a site's AshPostgres repo is, so the
  engine's tests run on the same Postgres features a site's would.
  """
  use AshPostgres.Repo, otp_app: :billboard

  @impl true
  def installed_extensions, do: ["ash-functions"]

  @impl true
  def prefer_transaction?, do: false

  @impl true
  def min_pg_version, do: %Version{major: 16, minor: 0, patch: 0}
end
