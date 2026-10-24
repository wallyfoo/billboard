# What a site's application starts for billboard: its repo, its PubSub,
# its endpoint, and the pages cache, which warms from the test database
# here, before the sandbox goes manual, as a site's does when its
# application starts.
{:ok, _supervisor} =
  Supervisor.start_link(
    [
      Billboard.Test.Repo,
      {Phoenix.PubSub, name: Billboard.Test.PubSub},
      Billboard.Test.Endpoint,
      Billboard.Cache
    ],
    strategy: :one_for_one,
    name: Billboard.Test.Supervisor
  )

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Billboard.Test.Repo, :manual)
