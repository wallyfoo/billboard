defmodule Billboard.Test.Fixtures do
  @moduledoc """
  Pages, versions, and sections on the shop. Writes skip authorization;
  a test of the policies passes an actor, such as `admin/0`, itself.
  """
  alias Billboard.Test.Shop

  @opts [authorize?: false]

  @doc "An actor: any actor is a signed-in user to billboard's policies."
  def admin, do: %{id: "admin"}

  @doc "A draft of the page at `path:` (`\"/\"` by default), making the page's record if it has none."
  def version_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    {:ok, page} = Shop.Pages.ensure_page(Map.get(attrs, :path, "/"), @opts)

    attrs
    |> Map.drop([:path])
    |> Map.put(:page_id, page.id)
    |> Shop.Pages.create_version!(@opts)
  end

  @doc "A section of `version` holding a `type` component made from `content`, through its create action."
  def section_fixture(version, type, content, attrs \\ %{}) do
    attrs
    |> Map.new()
    |> Map.merge(%{version_id: version.id, content: %Ash.Union{type: type, value: content}})
    |> Shop.Pages.create_section!(@opts)
  end

  @doc "Writes a section straight to the database, skipping its actions and their rules."
  def seed_section_fixture(version, type, content, attrs \\ %{}) do
    attrs
    |> Map.new()
    |> Map.merge(%{
      version_id: version.id,
      content: %Ash.Union{type: type, value: Billboard.Component.build!(type, content)}
    })
    |> Map.put_new(:key, Ecto.UUID.generate())
    |> then(&Ash.Seed.seed!(Shop.Section, &1))
  end

  @doc """
  Writes a section of `version` straight to its table, as it's stored:
  `type`, a component key, which needn't be one the shop has, and
  `fields`, string keys, as a site's rows hold a component it has since
  taken out of `components:`. Returns the section's key.
  """
  def stored_section_fixture(version, type, fields, attrs \\ %{}) do
    attrs = Map.new(attrs)
    key = Map.get(attrs, :key, Ecto.UUID.generate())
    now = DateTime.utc_now()

    Billboard.Test.Repo.insert_all("billboard_sections", [
      %{
        id: Ecto.UUID.bingenerate(),
        version_id: Ecto.UUID.dump!(version.id),
        parent_id: attrs[:parent_id] && Ecto.UUID.dump!(attrs[:parent_id]),
        key: key,
        anchor: attrs[:anchor],
        position: Map.get(attrs, :position, 0),
        content: %{
          "type" => to_string(type),
          "value" => Map.put(fields, "component", to_string(type))
        },
        inserted_at: now,
        updated_at: now
      }
    ])

    key
  end

  @doc "The content of the section `key` of the version `version_id`, as its table holds it."
  def stored_content(version_id, key) do
    %{rows: [[content]]} =
      Billboard.Test.Repo.query!(
        "SELECT content FROM billboard_sections WHERE version_id = $1 AND key = $2",
        [Ecto.UUID.dump!(version_id), key]
      )

    content
  end
end
