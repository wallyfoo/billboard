defmodule Billboard.Resource do
  @moduledoc """
  Which kind of billboard resource a module is. `use Billboard.Page`,
  `Billboard.Version`, and `Billboard.Section` each mark the resource
  they write. They, `use Billboard.Content`, and `use Billboard.Domain`
  read their site's answers through this module as they compile, and
  check them, so a mistake names the fix in the module that has it.
  """

  @doc "`:page`, `:version`, or `:section` for a billboard resource, and `nil` for any other module."
  @spec kind(module()) :: :page | :version | :section | nil
  defdelegate kind(module), to: Billboard.Resource.Kind, as: :of

  @typedoc "What a resource, the content union, or the domain reads from its site as it compiles."
  @type site :: %{
          module: module(),
          otp_app: atom(),
          repo: module() | nil,
          domain: module() | nil,
          resources: keyword(module()),
          components: [module()]
        }

  @names %{
    page: "Page",
    version: "Version",
    section: "Section",
    content: "Content",
    domain: "Domain"
  }

  # What each needs the site to name, besides itself.
  @needs %{
    page: [:domain, :repo],
    version: [:domain, :repo, :page, :section],
    section: [:domain, :repo, :version, :content],
    content: [],
    domain: [:page, :version, :section]
  }

  @doc false
  @spec site!(keyword(), Macro.Env.t(), atom()) :: site()
  def site!(opts, caller, kind) do
    user = "#{inspect(caller.module)}'s `use Billboard.#{@names[kind]}`"

    site =
      case Keyword.fetch(opts, :site) do
        {:ok, site} ->
          Macro.expand(site, caller)

        :error ->
          raise ArgumentError,
                "#{user} needs its site, such as `site: MySite.Billboard`, the module " <>
                  "that does `use Billboard.Site`"
      end

    unless match?({:module, _}, Code.ensure_compiled(site)) and Billboard.Site.Info.site?(site) do
      raise ArgumentError,
            "#{user} names #{inspect(site)} as its site, which doesn't `use Billboard.Site`. " <>
              "Name the site's module, or add `use Billboard.Site` to it"
    end

    answers = Billboard.Site.Info.answers(site)

    site = %{
      module: site,
      otp_app: Billboard.Site.Info.otp_app(site),
      repo: answers[:repo],
      domain: answers[:domain],
      resources: answers[:resources],
      components: answers[:components]
    }

    named_self!(site, caller.module, kind)
    Enum.each(@needs[kind], &need!(site, &1, user))
    site
  end

  # The site must name this module as the resource it writes, or the
  # engine would look for it elsewhere.
  defp named_self!(site, module, kind) when kind in [:page, :version, :section, :content] do
    case Keyword.get(site.resources, kind) do
      ^module ->
        :ok

      other ->
        raise ArgumentError,
              "#{inspect(site.module)} names #{if other, do: inspect(other), else: "no module"} " <>
                "as its #{kind}, not #{inspect(module)}. Add `#{kind}: #{inspect(module)}` to " <>
                "the `resources:` of its `use Billboard.Site`"
    end
  end

  defp named_self!(%{domain: module}, module, :domain), do: :ok

  defp named_self!(site, module, :domain) do
    raise ArgumentError,
          "#{inspect(site.module)} names #{inspect(site.domain)} as its domain, not " <>
            "#{inspect(module)}. Add `domain: #{inspect(module)}` to its `use Billboard.Site`"
  end

  defp need!(site, answer, _user) when answer in [:domain, :repo] do
    site[answer] ||
      raise ArgumentError,
            "#{inspect(site.module)} names no #{answer}, which its pages' resources need. " <>
              "Add `#{answer}: #{if answer == :repo, do: "MySite.Repo", else: "MySite.Pages"}` " <>
              "to its `use Billboard.Site`"
  end

  defp need!(site, resource, user) do
    Keyword.get(site.resources, resource) ||
      raise ArgumentError,
            "#{user} needs the site's #{resource}, but #{inspect(site.module)} names none. " <>
              "Add `#{resource}: MySite.Pages.#{@names[resource]}` to the `resources:` of its " <>
              "`use Billboard.Site`"
  end

  @doc false
  def only!(opts, allowed, name) do
    case Keyword.keys(opts) -- allowed do
      [] ->
        :ok

      unknown ->
        raise ArgumentError,
              "`use Billboard.#{name}` takes #{Enum.map_join(allowed, " and ", &"`#{&1}:`")}, " <>
                "not #{Enum.map_join(unknown, ", ", &inspect/1)}"
    end
  end

  @doc "The resource that `resource`'s relationship `name` points at."
  @spec related(module(), atom()) :: module()
  def related(resource, name), do: Ash.Resource.Info.relationship(resource, name).destination
end
