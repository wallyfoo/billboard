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

  @typedoc """
  One section `migrate_sections/3` changed, or would change: the page it's
  on (`page`, its pattern, `nil` for the library), whether it's in the
  page's `:live` version or its `:draft` (`version`), the section's `key`,
  and what it became (`to`), a component's key or `:deleted`.
  """
  @type migrated :: %{
          page: String.t() | nil,
          version: :live | :draft,
          key: String.t(),
          to: atom()
        }

  @doc """
  Moves every stored section of the component `from` to another
  component, or deletes them: on every page, in its live version and its
  draft, and in the shared library's, in one transaction, so either every
  section changes or none does. It's for retiring a component, before or
  after its module leaves `components:` (the page kinds guide's
  "Retiring a component" has a worked example). Billboard keeps no older
  versions, so these are all the stored sections there are.

  `from` is the key the sections are stored under, an atom or a string,
  as `:fees`, whether or not the site still lists it. `to` is one of:

    * a component key the site lists, as `:band`, which takes each
      section's stored fields as they are;
    * a function of a section's stored fields, a map with string keys
      (its parts maps too, and without the `component` tag), as
      `fields["title"]`, which returns `{key, fields}`, the component
      the section becomes and its fields, as `Billboard.Component.build/2`
      takes them, or `:delete`.

  Each new section is built with `Billboard.Component.build/2`, so it
  holds its component's defaults and passes its validations; one that
  doesn't stops the migration, and nothing changes. A section keeps its
  key, its place, its anchor, and its surface (drawn as its new kind's
  default where the site doesn't offer it). Deleting a Two columns
  section deletes its columns' sections, and deleting a column's section
  leaves its Two columns one short. The rules aren't checked here: what a
  migrated page breaks, the editor marks, and Publish waits for, as for
  any change.

  `opts`: `dry_run: true` changes nothing, but builds every new section
  all the same, and returns what it would have done. It runs no actions
  and no policies, as a database migration doesn't, so it needs no
  `actor:` or `authorize?: false`, and ignores them; call it from a
  script, a seed, or a release task, never on a visitor's request.
  Afterwards it refreshes `Billboard.Cache`, if it's running and a live
  section changed, and tells each changed page's editors.

  Returns `{:ok, migrated}`, a `t:migrated/0` for each section, in page
  order, or `{:error, %{page: pattern, version: status, key: key, error:
  error}}` for the first section whose new content didn't build. It
  raises `ArgumentError` for a component the site doesn't list, and for a
  function that returns anything else.

      # A site's own Banner, whose fields are a band's, becomes a band.
      {:ok, migrated} = MySite.Pages.migrate_sections(:banner, :band)

      # Or every one is taken off every page.
      {:ok, migrated} = MySite.Pages.migrate_sections(:banner, fn _fields -> :delete end)
  """
  @spec migrate_sections(atom() | String.t(), atom() | (map() -> term()), keyword()) ::
          {:ok, [migrated()]} | {:error, map()}
  def migrate_sections(from, to, opts \\ [])
      when (is_atom(from) or is_binary(from)) and (is_atom(to) or is_function(to, 1)) do
    opts = Keyword.validate!(opts, [:dry_run, :actor, :authorize?])
    dry_run? = Keyword.get(opts, :dry_run, false)
    to = migration(to)

    result =
      [Site.resource!(:section)]
      |> Ash.transact(fn ->
        from
        |> to_string()
        |> stored_sections()
        |> Enum.reduce_while([], fn row, done ->
          case migrate_section(row, to, dry_run?) do
            {:ok, change} -> {:cont, [change | done]}
            {:error, error} -> {:halt, {:error, Refused.exception(reason: error)}}
          end
        end)
        |> case do
          {:error, error} -> {:error, error}
          done -> Enum.reverse(done)
        end
      end)
      |> case do
        {:error, %Refused{reason: reason}} -> {:error, reason}
        other -> other
      end

    with {:ok, [_ | _] = changes} when not dry_run? <- result, do: tell(changes)
    result
  end

  defp migration(key) when is_atom(key) do
    known_key!(key)
    fn fields -> {key, fields} end
  end

  defp migration(fun), do: fun

  defp known_key!(key) do
    unless key in Billboard.Catalogue.keys() do
      raise ArgumentError,
            "migrate_sections/3 moves sections only to a component the site lists, and " <>
              "#{inspect(key)} isn't one. Add its module to `components:` in " <>
              "#{inspect(Site.get!())}'s `use Billboard.Site` first"
    end
  end

  # Every stored section of `type`, with its version's status and its
  # page's pattern, read as the table holds it, so a key the site no
  # longer lists reads as well as one it does.
  defp stored_sections(type) do
    [sections, versions, pages] =
      Enum.map([:section, :version, :page], &AshPostgres.DataLayer.Info.table(Site.resource!(&1)))

    %{rows: rows} =
      Site.repo!().query!(
        """
        SELECT s.id, s.key, s.content, v.status, p.pattern
        FROM "#{sections}" s
        JOIN "#{versions}" v ON v.id = s.version_id
        JOIN "#{pages}" p ON p.id = v.page_id
        WHERE s.content->>'type' = $1
        ORDER BY p.pattern NULLS FIRST, v.status, s.parent_id NULLS FIRST, s.position, s.key
        """,
        [type]
      )

    for [id, key, content, status, pattern] <- rows do
      %{
        id: id,
        key: key,
        fields: Map.delete(content["value"] || %{}, "component"),
        change: %{page: pattern, version: status(status), key: key}
      }
    end
  end

  defp status("live"), do: :live
  defp status("draft"), do: :draft

  defp migrate_section(row, to, dry_run?) do
    case to.(row.fields) do
      :delete ->
        unless dry_run?, do: write_section(row.id, :delete)
        {:ok, Map.put(row.change, :to, :deleted)}

      {key, fields} when is_atom(key) and is_map(fields) ->
        known_key!(key)

        with {:ok, value} <- Billboard.Component.build(key, fields),
             {:ok, stored} <- dump_content(%Ash.Union{type: key, value: value}) do
          unless dry_run?, do: write_section(row.id, stored)
          {:ok, Map.put(row.change, :to, key)}
        else
          {:error, error} -> {:error, Map.put(row.change, :error, error)}
          :error -> {:error, Map.put(row.change, :error, :not_stored)}
        end

      other ->
        raise ArgumentError,
              "migrate_sections/3's function returns `{key, fields}` or `:delete` for each " <>
                "section, but returned #{inspect(other)} for section #{inspect(row.key)}"
    end
  end

  defp dump_content(content) do
    attribute = Ash.Resource.Info.attribute(Site.resource!(:section), :content)
    Ash.Type.dump_to_native(attribute.type, content, attribute.constraints)
  end

  defp write_section(id, :delete) do
    table = AshPostgres.DataLayer.Info.table(Site.resource!(:section))
    Site.repo!().query!(~s(DELETE FROM "#{table}" WHERE id = $1), [id])
  end

  defp write_section(id, content) do
    table = AshPostgres.DataLayer.Info.table(Site.resource!(:section))

    Site.repo!().query!(
      ~s{UPDATE "#{table}" SET content = $1, updated_at = (now() AT TIME ZONE 'utc') WHERE id = $2},
      [content, id]
    )
  end

  # The writes skip the actions, and so their notifications: what
  # visitors see is read again, and each changed page's editors told,
  # where there's a cache and a PubSub to do it with, as there may not be
  # in a bare script.
  defp tell(changes) do
    if Process.whereis(Cache) && Enum.any?(changes, &(&1.version == :live)), do: Cache.refresh()

    if Process.whereis(Site.pubsub!()) do
      for pattern <- changes |> Enum.map(& &1.page) |> Enum.uniq() do
        Phoenix.PubSub.broadcast(
          Site.pubsub!(),
          page_topic(pattern),
          {:page_draft_changed, pattern}
        )
      end
    end

    :ok
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
