defmodule Billboard.Section do
  @moduledoc """
  One component placed on a version. `content` is the site's content
  union (`Billboard.Content`), so its type names the component and its
  value holds the component's fields.

      defmodule MySite.Pages.Section do
        use Billboard.Section, site: MySite.Billboard
      end

  `table:` names its table, `"billboard_sections"` by default.

  `key` survives being copied into a draft and committed, so the editor
  can follow a section from the live version into its draft, and a shared
  section placed on other pages still finds its source after the library
  is committed again. `anchor` is the section's DOM id on the public page,
  for in-page links and tests, so it is unique within a version. A section
  without one takes a DOM id made from its key (`dom_id/1`). `surface`
  names the ground it sits on, from `Billboard.Surfaces`, or is `nil` for
  its kind's default.

  Like versions, sections of a draft are hidden from visitors.

  A section inside a Two columns section has that section as its parent.
  """

  @doc false
  defmacro __using__(opts) do
    Billboard.Resource.only!(opts, [:site, :table], "Section")
    site = Billboard.Resource.site!(opts, __CALLER__, :section)
    table = Keyword.get(opts, :table, "billboard_sections")
    version = Macro.var(:version, nil)

    quote do
      require unquote(site.module)

      use Ash.Resource,
        otp_app: unquote(site.otp_app),
        domain: unquote(site.domain),
        data_layer: AshPostgres.DataLayer,
        authorizers: [Ash.Policy.Authorizer],
        simple_notifiers: [Billboard.Notifier]

      @persist {:billboard_resource, :section}

      postgres do
        table unquote(table)
        repo unquote(site.repo)

        custom_indexes do
          index [:parent_id]
        end

        references do
          reference :version, on_delete: :delete
          reference :parent, on_delete: :delete
        end
      end

      actions do
        defaults [:read]

        create :create do
          primary? true
          accept [:version_id, :parent_id, :anchor, :content, :key, :surface]
          change Billboard.Section.Changes.AppendToSiblings
          validate Billboard.Section.Validations.DraftOnly, before_action?: true
          validate Billboard.Section.Validations.ColumnParent
          validate Billboard.Section.Validations.AnchorAvailable
          validate Billboard.Section.Validations.SurfaceOffered
        end

        # A copy keeps the surface its source was given, unchecked by
        # `SurfaceOffered`. Checking it would refuse to make a draft at all, and
        # so lock the page out of the editor, once the site stops offering a
        # surface a live section still names.
        create :copy do
          description "A section copied from another version, keeping its key and place."
          accept [:version_id, :parent_id, :anchor, :content, :key, :surface, :position]
          validate Billboard.Section.Validations.DraftOnly, before_action?: true
          validate Billboard.Section.Validations.ColumnParent
          validate {Billboard.Section.Validations.AnchorAvailable, siblings: false}
        end

        update :update do
          primary? true
          accept [:anchor, :content, :surface]
          require_atomic? false
          validate Billboard.Section.Validations.DraftOnly, before_action?: true
          validate Billboard.Section.Validations.AnchorAvailable
          validate Billboard.Section.Validations.SurfaceOffered
        end

        update :place do
          accept [:position]
          require_atomic? false
          validate Billboard.Section.Validations.DraftOnly, before_action?: true
        end

        action :arrange do
          description """
          Puts a version's top-level sections in the given order. `order` lists
          every top-level section's id exactly once.
          """

          transaction? true
          argument :version_id, :uuid, allow_nil?: false
          argument :order, {:array, :uuid}, allow_nil?: false
          run Billboard.Section.Arrange
        end

        destroy :destroy do
          primary? true
          description "Removes a section from a draft, with its columns' sections."
          require_atomic? false
          validate Billboard.Section.Validations.DraftOnly, before_action?: true
          validate Billboard.Section.Validations.Removable
        end
      end

      policies do
        policy action_type(:read) do
          authorize_if expr(unquote(version).status == :live)
          authorize_if actor_present()
        end

        policy action_type([:create, :update, :destroy, :action]) do
          authorize_if actor_present()
        end
      end

      attributes do
        uuid_primary_key :id

        attribute :key, :string do
          allow_nil? false
          default &Ecto.UUID.generate/0
          public? true
        end

        attribute :anchor, :string do
          public? true
          constraints match: ~r/^[a-z][a-z0-9-]*$/, max_length: 40
        end

        attribute :position, :integer, allow_nil?: false, default: 0, public?: true
        attribute :content, unquote(site.resources[:content]), allow_nil?: false, public?: true

        # A name from `Billboard.Surfaces`. Most sections leave it out and take
        # their kind's default, so that changing the default changes them too.
        attribute :surface, :string, allow_nil?: true, public?: true

        timestamps()
      end

      relationships do
        belongs_to :version, unquote(site.resources[:version]), allow_nil?: false, public?: true
        belongs_to :parent, __MODULE__, public?: true

        has_many :children, __MODULE__ do
          destination_attribute :parent_id
          sort position: :asc
          public? true
        end
      end

      identities do
        identity :unique_key, [:version_id, :key]

        # Sections without an anchor don't clash: Postgres treats NULLs as distinct.
        identity :unique_anchor, [:version_id, :anchor]
      end

      @doc "The section's DOM id on the public page: its anchor, or one made from its key."
      defdelegate dom_id(section), to: Billboard.Section
    end
  end

  @doc """
  The section's DOM id on the public page: its anchor, or one made from
  its key.
  """
  @spec dom_id(%{anchor: String.t() | nil, key: String.t()}) :: String.t()
  def dom_id(%{anchor: anchor}) when is_binary(anchor), do: anchor
  def dom_id(%{key: key}), do: "section-#{key}"
end
