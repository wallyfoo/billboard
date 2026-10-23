defmodule Billboard.Version do
  @moduledoc """
  One arrangement of a page's sections. The live version is the one
  visitors see; the draft holds the changes being made to it. A page has
  at most one of each, and nothing else: committing replaces the live
  version with the draft, and discarding deletes the draft. A version
  belongs to its page (`Billboard.Page`).

      defmodule MySite.Pages.Version do
        use Billboard.Version, site: MySite.Billboard
      end

  `table:` names its table, `"billboard_versions"` by default. Two
  partial unique indexes, `<table>_one_live_per_page_index` and
  `<table>_one_draft_per_page_index`, keep a page to one of each.

  Visitors may read a live version; drafts, and every change, need an
  actor.
  """

  @doc false
  defmacro __using__(opts) do
    Billboard.Resource.only!(opts, [:site, :table], "Version")
    site = Billboard.Resource.site!(opts, __CALLER__, :version)
    table = Keyword.get(opts, :table, "billboard_versions")
    [status, page_id, parent_id] = Enum.map([:status, :page_id, :parent_id], &Macro.var(&1, nil))

    quote do
      require unquote(site.module)

      use Ash.Resource,
        otp_app: unquote(site.otp_app),
        domain: unquote(site.domain),
        data_layer: AshPostgres.DataLayer,
        authorizers: [Ash.Policy.Authorizer],
        simple_notifiers: [Billboard.Notifier]

      @persist {:billboard_resource, :version}

      postgres do
        table unquote(table)
        repo unquote(site.repo)

        identity_wheres_to_sql one_live_per_page: "status = 'live'",
                               one_draft_per_page: "status = 'draft'"

        references do
          reference :page, on_delete: :delete
        end
      end

      actions do
        defaults [:read]

        read :live do
          filter expr(unquote(status) == :live)
          prepare build(load: [:page, sections: :children])
        end

        read :drafts do
          description "Every page's draft, with its page, so the editor can mark the pages with changes."
          filter expr(unquote(status) == :draft)
          prepare build(load: [:page])
        end

        read :draft do
          get? true
          argument :page_id, :uuid, allow_nil?: false
          filter expr(unquote(status) == :draft and unquote(page_id) == ^arg(:page_id))
          prepare build(load: [:page, sections: :children])
        end

        create :create do
          primary? true
          description "A page's draft. The live version only ever comes from committing one."
          accept [:page_id]
        end

        destroy :destroy do
          primary? true
        end

        update :make_live do
          description "Makes a draft the live version. Only `:commit` uses this, once the old live version is gone."
          accept []
          change set_attribute(:status, :live)
          change set_attribute(:committed_at, &DateTime.utc_now/0)
        end
      end

      policies do
        policy action_type(:read) do
          authorize_if expr(unquote(status) == :live)
          authorize_if actor_present()
        end

        policy action_type([:create, :update, :destroy, :action]) do
          authorize_if actor_present()
        end
      end

      attributes do
        uuid_primary_key :id

        attribute :status, :atom do
          allow_nil? false
          default :draft
          public? true
          constraints one_of: [:draft, :live]
        end

        attribute :committed_at, :utc_datetime_usec, public?: true

        timestamps()
      end

      relationships do
        belongs_to :page, unquote(site.resources[:page]) do
          allow_nil? false
          public? true
        end

        has_many :sections, unquote(site.resources[:section]) do
          filter expr(is_nil(unquote(parent_id)))
          sort position: :asc
          public? true
        end
      end

      # Partial unique indexes. As identities, a clash comes back as a
      # validation error rather than a database exception.
      identities do
        identity :one_live_per_page, [:page_id], where: expr(unquote(status) == :live)
        identity :one_draft_per_page, [:page_id], where: expr(unquote(status) == :draft)
      end
    end
  end
end
