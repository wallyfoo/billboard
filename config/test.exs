import Config

config :billboard, site: Billboard.Test.Shop

# The test site's repo and its domains. Only the library's own tests have
# a database; a site's config is its own.
config :billboard, ecto_repos: [Billboard.Test.Repo], ash_domains: []

config :billboard, Billboard.Test.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "billboard_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  # Out of `priv/`, which ships with the library.
  priv: "test/support/postgres",
  snapshots_path: "test/support/postgres/resource_snapshots"

config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

config :logger, level: :warning
