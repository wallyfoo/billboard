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
end
