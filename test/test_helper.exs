# What a site's application starts for billboard: its repo and PubSub.
{:ok, _supervisor} =
  Supervisor.start_link(
    [Billboard.Test.Repo, {Phoenix.PubSub, name: Billboard.Test.PubSub}],
    strategy: :one_for_one,
    name: Billboard.Test.Supervisor
  )

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Billboard.Test.Repo, :manual)
