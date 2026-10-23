defmodule Billboard.Page do
  @moduledoc """
  A builder page's record, keyed by its route pattern (`Billboard.Directory`),
  which owns the page's versions. The shared-sections library is the page
  with no pattern, and there is only ever one.

      defmodule MySite.Pages.Page do
        use Billboard.Page, site: MySite.Billboard
      end

  `table:` names its table, `"billboard_pages"` by default. Two unique
  indexes keep the pages apart: `<table>_unique_pattern_index`, one record
  to a pattern, and `<table>_one_library_index`, one library.

  A page's record is made on its first edit (`Billboard.Pages.ensure_page/2`),
  so a page that has never been edited has none, and visitors see its
  starter. Anyone may read a page's record, and any actor make one.
  """

  @doc false
  defmacro __using__(opts) do
    Billboard.Resource.only!(opts, [:site, :table], "Page")
    site = Billboard.Resource.site!(opts, __CALLER__, :page)
    table = Keyword.get(opts, :table, "billboard_pages")
    pattern = Macro.var(:pattern, nil)

    quote do
      require unquote(site.module)

      use Ash.Resource,
        otp_app: unquote(site.otp_app),
        domain: unquote(site.domain),
        data_layer: AshPostgres.DataLayer,
        authorizers: [Ash.Policy.Authorizer]

      @persist {:billboard_resource, :page}

      postgres do
        table unquote(table)
        repo unquote(site.repo)

        custom_indexes do
          index ["(pattern IS NULL)"] do
            name unquote(table <> "_one_library_index")
            unique true
            where "pattern IS NULL"
          end
        end
      end

      actions do
        defaults [:read]

        read :library do
          get? true
          filter expr(is_nil(unquote(pattern)))
        end

        read :by_pattern do
          get? true
          argument :pattern, :string, allow_nil?: false
          filter expr(unquote(pattern) == ^arg(:pattern))
        end

        create :create do
          primary? true
          description "A builder page, or, with no pattern, the shared-sections library."
          accept [:pattern]
        end
      end

      policies do
        policy action_type(:read) do
          authorize_if always()
        end

        policy action_type(:create) do
          authorize_if actor_present()
        end
      end

      attributes do
        uuid_primary_key :id

        attribute :pattern, :string, public?: true

        timestamps()
      end

      identities do
        identity :unique_pattern, [:pattern]
      end
    end
  end
end
