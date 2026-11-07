defmodule Billboard.Pages do
  @moduledoc """
  The page engine's functions. Each page has at most two versions of its
  layout: the live one, and a draft of uncommitted changes. A version
  holds ordered sections, and each section's content is one of the
  site's components, in its content union (`Billboard.Content`). A page's
  record is made on its first edit. The site's domain (`Billboard.Domain`)
  delegates these by the same names, so a site calls
  `MySite.Pages.page_for/1`.

  Components are defined in code, each a `use Billboard.Component` module
  the site lists, and drawn by the site's own markup. Layouts are made in
  the admin: every change an editor makes goes through `change_draft/3`,
  and `commit` makes the draft live.

  They reach the site's resources through its domain's code interfaces
  (`Billboard.Site.domain!/0`), which `use Billboard.Domain` defines,
  such as the domain's `edit_page/2` and `arrange_sections/3`. The
  actions behind those (`Billboard.Version.Edit`, `Billboard.Version.Commit`,
  and `Billboard.Version.Discard`) write to the resource they run on, but
  find the page and its draft through the configured site, so an app has
  one site.
  `page_for/1`, `shared_sections/0`, and `shared_section/1` read
  `Billboard.Cache`, not the database, and the subscribe functions use
  the site's PubSub (`Billboard.Site.pubsub!/0`).
  """

  require Ash.Query

  alias Billboard.{Cache, Directory, Site, Snapshot}
  alias Billboard.Errors.Refused

  @doc """
  The page's draft, with its sections and their children, or nil when
  nobody is editing it. Unlike the domain's `edit_page/2`, this never
  creates anything.

  Inside a transaction, `lock: :for_update` holds the draft's row until it
  ends, so no section of it changes meanwhile (see
  `Billboard.Section.Validations.DraftOnly`). Commit and discard take it.
  """
  def draft_for(pattern, opts \\ []) do
    {lock, opts} = Keyword.pop(opts, :lock)

    case existing_page(pattern, opts) do
      {:ok, nil} -> {:ok, nil}
      {:ok, page} -> domain().get_draft(page.id, locking(lock) ++ opts)
      error -> error
    end
  end

  @doc """
  The page record for `pattern` (`nil` for the library), made if it has
  none. A page's first edit makes it, through `Billboard.Version.Edit`.
  """
  def ensure_page(pattern, opts \\ []) do
    case existing_page(pattern, opts) do
      {:ok, nil} -> domain().create_page(%{pattern: pattern}, opts)
      other -> other
    end
  end

  @doc """
  Makes `pattern`'s draft if this is the page's first change, then runs
  `fun` with it, as every editor change does. `fun` gets the draft (with
  `sections: :children` loaded) and a map from section key to the draft's
  section, children included, and returns `:ok`, `{:ok, result}`, or
  `{:error, error}`. Returns `{:ok, result}` (`nil` for `:ok`) or
  `{:error, error}`.

  Both happen in one transaction, so a change that fails takes back the
  draft it made: a refused first change leaves no draft behind.

  When two admins make a page's first change at the same instant, the
  second one's draft, or the page record made with it, clashes with the
  first's, and that transaction is gone. This tries once more, in a fresh
  transaction, which finds what the first admin made.
  """
  @spec change_draft(
          String.t() | nil,
          (struct(), %{String.t() => struct()} -> term()),
          keyword()
        ) ::
          {:ok, term()} | {:error, term()}
  def change_draft(pattern, fun, opts \\ []) do
    # The clash is looked for before `fun`'s own reason is unwrapped, so
    # a change `fun` turns down is never tried again, whatever its reason.
    result =
      case change_draft_once(pattern, fun, opts) do
        {:error, error} ->
          if first_edit_clash?(error),
            do: change_draft_once(pattern, fun, opts),
            else: {:error, error}

        result ->
          result
      end

    case result do
      {:error, %Refused{reason: reason}} -> {:error, reason}
      result -> result
    end
  end

  # `Ash.transact/2` returns what the function returns, wrapped in `:ok`,
  # and makes any error an Ash error, so `fun`'s own reason travels out in
  # a `Refused`.
  defp change_draft_once(pattern, fun, opts) do
    Ash.transact([Site.resource!(:version), Site.resource!(:section)], fn ->
      with {:ok, draft} <- domain().edit_page(pattern, opts) do
        case fun.(draft, sections_by_key(draft.sections)) do
          :ok -> nil
          {:ok, result} -> result
          {:error, reason} -> {:error, Refused.exception(reason: reason)}
        end
      end
    end)
  end

  @doc false
  # Public for its test: a real race of two first edits can't be staged
  # inside one sandbox. A change `fun` turned down is never a clash.
  def first_edit_clash?(%Refused{}), do: false

  def first_edit_clash?(%{errors: errors}) when is_list(errors),
    do: Enum.any?(errors, &first_edit_clash?/1)

  def first_edit_clash?(%{private_vars: vars}) when is_list(vars),
    do: Keyword.get(vars, :constraint) in first_edit_constraints()

  def first_edit_clash?(_error), do: false

  # The unique indexes a first edit can clash on: the draft's, and the
  # page's, which may be the library's. Their names follow the site's
  # tables, as AshPostgres names identities and as `use Billboard.Page`
  # names the library's index.
  defp first_edit_constraints do
    versions = AshPostgres.DataLayer.Info.table(Site.resource!(:version))
    pages = AshPostgres.DataLayer.Info.table(Site.resource!(:page))

    [
      "#{versions}_one_draft_per_page_index",
      "#{pages}_unique_pattern_index",
      "#{pages}_one_library_index"
    ]
  end

  defp sections_by_key(sections),
    do: Map.new(sections ++ Enum.flat_map(sections, & &1.children), &{&1.key, &1})

  @typedoc """
  A section for `put_page/3`: the component's key, and its content, a map
  of the component's fields, as `Billboard.Component.build/2` takes, with
  its parts as maps too. The rest are optional: `surface`, a name from the
  site's surfaces for its kind (`Billboard.Surfaces`), or nil for its
  kind's default; `anchor`, its DOM id on the page; `key`, which the
  editor follows it by, made for it if not given; and `children`, a Two
  columns section's two sections, each one of these.
  """
  @type section_spec :: %{
          required(:type) => atom(),
          required(:content) => map(),
          optional(:surface) => String.t() | nil,
          optional(:anchor) => String.t() | nil,
          optional(:key) => String.t(),
          optional(:children) => [section_spec()]
        }

  @section_spec_keys [:type, :content, :surface, :anchor, :key, :children]

  @doc """
  Makes the page at `pattern` (`nil` for the library) hold exactly
  `sections`, in order, and publishes it, so visitors see it: what a
  site's seeds do, to rebuild a page in a fresh database. Each section
  is a `t:section_spec/0`.

  It throws away the page's draft, if it has one, writes a new draft
  holding only `sections`, and commits it, which replaces the live
  version, all in one transaction: so running it again puts the same
  page back, whatever was published or drafted since, and a page that
  breaks a rule (`Billboard.Rules`), such as one that doesn't open with
  its hero, changes nothing and gives the commit's error.

  `opts` go to each of the domain's actions, so a caller with no
  signed-in user passes `authorize?: false`, or an `actor:`. With
  `publish: false`, it leaves the draft for the editor to publish, and
  returns it. Returns `{:ok, version}`, the live version (or the draft),
  with its sections and their children loaded, or `{:error, error}`.
  """
  @spec put_page(String.t() | nil, [section_spec()], keyword()) ::
          {:ok, struct()} | {:error, term()}
  def put_page(pattern, sections, opts \\ []) when is_list(sections) do
    {publish?, opts} = Keyword.pop(opts, :publish, true)
    Enum.each(sections, &check_spec!/1)

    [Site.resource!(:page), Site.resource!(:version), Site.resource!(:section)]
    |> Ash.transact(fn ->
      with :ok <- known_page(pattern),
           :ok <- domain().discard_page(pattern, opts),
           {:ok, page} <- ensure_page(pattern, opts),
           {:ok, draft} <- domain().create_version(%{page_id: page.id}, opts),
           :ok <- put_sections(sections, draft.id, nil, opts),
           {:ok, _version} <-
             if(publish?, do: domain().commit_page(pattern, opts), else: {:ok, nil}) do
        version_with_sections(page.id, publish?, opts)
      end
    end)
    |> case do
      {:ok, {:ok, version}} -> {:ok, version}
      {:ok, {:error, error}} -> {:error, error}
      {:ok, version} -> {:ok, version}
      error -> error
    end
  end

  defp check_spec!(%{type: type, content: content} = spec)
       when is_atom(type) and is_map(content) do
    case Map.keys(spec) -- @section_spec_keys do
      [] ->
        Enum.each(Map.get(spec, :children) || [], &check_spec!/1)

      extra ->
        raise ArgumentError,
              "a section for put_page/3 has keys it doesn't take: #{inspect(extra)}. " <>
                "Give only #{inspect(@section_spec_keys)}"
    end
  end

  defp check_spec!(spec) do
    raise ArgumentError,
          "put_page/3 takes each section as a map with `type:`, a component's key, and " <>
            "`content:`, a map of its fields, as %{type: :hero, content: %{heading: \"Welcome\"}}. " <>
            "It was given #{inspect(spec)}"
  end

  defp known_page(pattern) do
    if Directory.fetch(pattern),
      do: :ok,
      else:
        {:error,
         Ash.Error.Changes.InvalidArgument.exception(
           field: :pattern,
           message: "there is no such page"
         )}
  end

  defp put_sections(specs, version_id, parent_id, opts) do
    Enum.reduce_while(specs, :ok, fn spec, :ok ->
      case put_section(spec, version_id, parent_id, opts) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp put_section(spec, version_id, parent_id, opts) do
    with {:ok, content} <- Billboard.Component.build(spec.type, spec.content),
         {:ok, section} <-
           domain().create_section(
             %{
               version_id: version_id,
               parent_id: parent_id,
               content: %Ash.Union{type: spec.type, value: content},
               surface: Map.get(spec, :surface),
               anchor: Map.get(spec, :anchor),
               key: Map.get(spec, :key) || Ecto.UUID.generate()
             },
             opts
           ) do
      put_sections(Map.get(spec, :children) || [], version_id, section.id, opts)
    end
  end

  defp version_with_sections(page_id, false, opts), do: domain().get_draft(page_id, opts)

  defp version_with_sections(page_id, true, opts) do
    Site.resource!(:version)
    |> Ash.Query.for_read(:live, %{}, opts)
    |> Ash.Query.filter(page_id == ^page_id)
    |> Ash.read_one(opts)
  end

  @doc """
  Swaps a Two columns section's columns: the right one goes left, and the
  left one right. `columns` must have its `children` loaded. Like every
  move, it only works on a draft's section, and, as with the domain's
  `arrange_sections/3`, not on a fixed page.
  """
  @spec swap_columns(struct(), keyword()) :: :ok | {:error, term()}
  def swap_columns(columns, opts \\ [])

  def swap_columns(
        %{content: %Ash.Union{type: :columns}, children: [left, right]} = columns,
        opts
      ) do
    Ash.transact([Site.resource!(:version), Site.resource!(:section)], fn ->
      with :ok <- not_fixed(columns.version_id, opts),
           {:ok, _right} <- domain().place_section(right, 0, opts),
           {:ok, _left} <- domain().place_section(left, 1, opts),
           do: :ok
    end)
    |> case do
      {:ok, :ok} -> :ok
      error -> error
    end
  end

  def swap_columns(_section, _opts) do
    {:error,
     Ash.Error.Changes.InvalidArgument.exception(
       field: :key,
       message: "only Two columns, holding two sections, can swap sides"
     )}
  end

  defp not_fixed(version_id, opts) do
    with {:ok, version} <- domain().get_version(version_id, [load: [:page]] ++ opts) do
      if Directory.fixed?(version.page.pattern),
        do:
          {:error,
           Ash.Error.Changes.InvalidArgument.exception(
             field: :key,
             message: "this page's sections are fixed"
           )},
        else: :ok
    end
  end

  @doc """
  Drops the `{:page_draft_changed, pattern}` messages waiting in the
  caller's mailbox. A change arrives as a burst, one message per row, and
  an editor that has just made a change reads the page itself, so it
  needn't read it again for each of its own messages.
  """
  def drain_page_changes(pattern) do
    receive do
      {:page_draft_changed, ^pattern} -> drain_page_changes(pattern)
    after
      0 -> :ok
    end
  end

  @doc """
  What the page at route `pattern` (`nil` for the shared-sections library)
  shows visitors: its live version, else its starter. Both come from
  `Billboard.Cache`, with their sections and the sections' children
  loaded, so this never reads the database while the cache is full.

  Raises `ArgumentError` for a page the builder doesn't know.
  """
  @spec page_for(String.t() | nil) :: struct()
  def page_for(pattern) do
    Snapshot.page(Cache.snapshot(), pattern) || Site.starter(Directory.fetch!(pattern).pattern)
  end

  @doc """
  The shared-library sections by key: its live version's, else its
  starter's.
  """
  @spec shared_sections() :: %{String.t() => struct()}
  def shared_sections, do: Map.new(page_for(nil).sections, &{&1.key, &1})

  @doc "The shared-library section with `key`, or `nil` if it has left the library."
  @spec shared_section(String.t()) :: struct() | nil
  def shared_section(key), do: Map.get(shared_sections(), key)

  @doc """
  Subscribes the caller to what visitors see. Each change, a commit or a
  change to the data behind a starter, arrives as
  `{:pages_updated, node, %Billboard.Snapshot{}}`.
  """
  def subscribe, do: Phoenix.PubSub.subscribe(Site.pubsub!(), Cache.topic())

  @doc """
  Subscribes the caller to `pattern`'s page, as its editors do. Any
  change to its draft, including making, committing, or discarding it,
  arrives as `{:page_draft_changed, pattern}`.
  """
  def subscribe_page(pattern),
    do: Phoenix.PubSub.subscribe(Site.pubsub!(), page_topic(pattern))

  @doc "Undoes `subscribe_page/1`, as an editor does when it leaves a page."
  def unsubscribe_page(pattern),
    do: Phoenix.PubSub.unsubscribe(Site.pubsub!(), page_topic(pattern))

  @doc "The PubSub topic for `pattern`'s page (`nil` for the library)."
  def page_topic(nil), do: "pages:shared"
  def page_topic(pattern), do: "pages:page:" <> pattern

  defp locking(nil), do: []
  defp locking(lock), do: [query: Ash.Query.lock(Site.resource!(:version), lock)]

  defp existing_page(nil, opts), do: domain().fetch_library_page(opts)
  defp existing_page(pattern, opts), do: domain().fetch_page(pattern, opts)

  defp domain, do: Site.domain!()
end
