defmodule Billboard.EditorLive do
  @moduledoc """
  The page editor: the page itself, drawn by the site's own renderers
  (`Billboard.Sections.page/1`) in the site's layout, under a slim bar for
  picking a page and publishing it. Clicking a section opens it: its
  words are typed into where they sit, and its editor
  (`Billboard.EditorLive.SectionEditor`) changes the rest. One section is
  open at a time, by key (`@open`). View as visitor draws the page with
  none of the editor's marks.

  A site mounts it in its router, inside the `live_session` its signed-in
  pages use, with `billboard_editor` (`Billboard.Editor.Router`), and the
  editor acts as that session's `current_scope.user`. Every address in
  the editor is `Billboard.Editor.path/3`'s.

  A page has its live layout (or, until its first commit, its starter)
  and, while someone is editing it, one draft. The editor always shows the
  draft if there is one, and otherwise the live layout. It names sections
  by key, not id, because a draft's sections keep the keys of the live
  sections they were copied from, so an open section stays open through
  the first change that makes the draft.

  Every change goes through `with_draft/2`, which makes the page's draft on
  the first change and applies the change to it. The live page changes
  only when the draft is published (`"commit"`, as the code calls it).
  The rules mark the sections they find a problem with, and the bar
  counts the problems: an error holds Publish back, and a warning only
  advises.

  A section is added at a place between two others
  (`Billboard.EditorLive.Palette.gap/1`), which opens the palette there,
  and arrives open, to be typed into. A fixed page has no places to add
  one.

  The page is in the query string (`?page=/contact`), and so is a section
  to open (`&open=KEY`); the shared-sections library, whose pattern is
  `nil`, is `?page=shared`. A page whose route has a parameter is drawn
  with the site's sample (`Billboard.Context.sample/1`). The library has
  no page of its own: its sections are drawn one after another under the
  site's header, with its name and what it's for in the hero's place,
  and edited like any page's. A page's Shared section is edited there, by
  way of its Edit in library.

  The site's own page components may send events of their own, such as a
  filter's, which the editor draws them sending: it does nothing with
  those the site names in `page_events:` (`Billboard.Site`), and logs a
  warning for any other event it doesn't know.
  """
  use Phoenix.LiveView

  alias Billboard.{Catalogue, Context, Directory, Editor, Layout, Pages, Resolver, Rules}
  alias Billboard.Editor.Components
  alias Billboard.EditorLive.{Filler, Palette, SectionEditor}
  alias Billboard.Sections
  alias Billboard.Sections.{EditorFields, Words}
  alias Phoenix.LiveView.JS

  import Billboard.EditorLive.Messages

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    unless match?(%{user: user} when not is_nil(user), socket.assigns[:current_scope]) do
      raise ArgumentError,
            "the page editor needs `@current_scope`, with the signed-in user as " <>
              "`current_scope.user`. Mount it with `billboard_editor` inside the " <>
              "live_session your signed-in pages use"
    end

    router = socket.router

    {:ok,
     socket
     |> assign(:page_title, "Pages")
     |> assign(:pages, Directory.pages())
     |> assign(page: nil, draft: nil, version: nil, issues: [], errors: [])
     |> assign(library: [], library_version: nil, palette: [], adding_at: nil)
     |> assign(drafts: MapSet.new(), shared_uses: %{}, glyphs: Palette.glyphs())
     |> assign(open: nil, open_in_url?: false, mode: :edit, context: %{}, data: %{})
     |> assign(:current_path, nil)
     |> assign(:back, Editor.mount(router).back)
     |> assign(:editor_path, fn pattern, opts -> Editor.path(router, pattern, opts) end)
     |> assign(:choices, Context.choices_for(EditorFields.choice_names()))
     |> assign(:site, Layout.site())}
  end

  # Another page is read afresh, with its sample context, and opens with
  # no section open. `&open=KEY` opens one, while editing, and brings it
  # into view, as Edit in library does from wherever the page was
  # scrolled. The address keeps it until another section opens, or none
  # is, and then names the page alone (`forget_open_in_url/1`): a patch
  # here, as the LiveView mounts, would mount it again without the
  # section.
  @impl true
  def handle_params(params, _uri, socket) do
    page = page_from_param(params["page"])

    socket =
      if page == socket.assigns.page,
        do: socket,
        else:
          socket
          |> follow(page)
          |> assign(page: page, open: nil, adding_at: nil)
          |> assign(:context, Context.sample(page))
          |> load_page()

    case params["open"] do
      key when is_binary(key) and socket.assigns.mode == :edit ->
        {:noreply, socket |> open_section(key) |> reveal() |> assign(:open_in_url?, true)}

      key when is_binary(key) ->
        {:noreply, assign(socket, :open_in_url?, true)}

      _none ->
        {:noreply, assign(socket, :open_in_url?, false)}
    end
  end

  # Opening a section takes the focus into its controls header, or, when
  # the canvas says which of its words were clicked (`words`, their path),
  # into them; closing it hands the focus back to the button that opens
  # it.
  @impl true
  def handle_event("open_section", %{"key" => key} = params, %{assigns: %{mode: :edit}} = socket) do
    at =
      case params["words"] do
        path when is_binary(path) -> [Words.id(key, path)]
        _none -> []
      end

    {:noreply, socket |> open_section(key, at) |> forget_open_in_url()}
  end

  def handle_event("open_section", _params, socket), do: {:noreply, socket}

  # Words still being typed in the open section send themselves as the
  # field loses the focus, which a click on Done or elsewhere does first.
  def handle_event("close_section", _params, socket) do
    socket =
      case socket.assigns.open do
        nil -> socket
        key -> focus(socket, ["open-#{key}"])
      end

    {:noreply, socket |> assign(:open, nil) |> forget_open_in_url()}
  end

  def handle_event("mode", %{"mode" => mode}, socket) when mode in ~w(edit view) do
    mode = if mode == "edit", do: :edit, else: :view
    {:noreply, socket |> assign(mode: mode, open: nil, adding_at: nil) |> forget_open_in_url()}
  end

  # Opens the palette at a place between sections (`Palette.gap/1`), or
  # closes it, there, and takes the focus into it, to its first entry that
  # can be added.
  def handle_event("palette", %{"at" => at}, %{assigns: %{mode: :edit}} = socket) do
    case place(socket, at) do
      {:ok, at} when at == socket.assigns.adding_at ->
        {:noreply, close_palette(socket)}

      {:ok, at} ->
        first =
          for {_category, options} <- socket.assigns.palette,
              %{disabled: nil, entry: entry} <- options,
              do: "section-palette-#{entry.key}"

        {:noreply,
         socket
         |> assign(:adding_at, at)
         |> focus(Enum.take(first, 1) ++ ["section-palette"], scroll: true)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("palette", _params, socket), do: {:noreply, socket}

  # A click away from the palette says where it was open, and closes it
  # only if it still is there. Escape closes it wherever it is. Tabbing
  # out of it (`stay`) leaves the focus where it went.
  def handle_event("close_palette", params, %{assigns: %{mode: :edit}} = socket) do
    cond do
      Map.has_key?(params, "at") and
          place(socket, params["at"]) != {:ok, socket.assigns.adding_at} ->
        {:noreply, socket}

      params["stay"] == true ->
        {:noreply, assign(socket, :adding_at, nil)}

      true ->
        {:noreply, close_palette(socket)}
    end
  end

  def handle_event("close_palette", _params, socket), do: {:noreply, socket}

  # A new section goes where the palette was opened (`at`), or, sent
  # without a place, at the end, and opens with the focus in its first
  # words, ready to be typed over. New Two columns open their left
  # column, since the pair has no words of its own: its header is a
  # click away, by the column's "Two columns".
  def handle_event(
        "add_section",
        %{"component" => component} = params,
        %{assigns: %{mode: :edit}} = socket
      ) do
    option = Enum.find(palette_options(socket), &(Atom.to_string(&1.entry.key) == component))
    at = Map.get_lazy(params, "at", fn -> length(socket.assigns.version.sections) end)

    case {option, place(socket, at)} do
      {%{disabled: nil, entry: entry}, {:ok, at}} ->
        socket = assign(socket, :adding_at, nil)

        case change(socket, fn draft, _sections -> add_section(socket, draft, entry.key, at) end) do
          {{:ok, section}, socket} ->
            {:noreply, open_new(socket, section_to_open(socket, section.key))}

          # The palette has closed; the focus goes back to where it was.
          {:error, socket} ->
            {:noreply, focus(socket, ["section-add-at-#{at}", "page-picker-toggle"])}
        end

      {%{disabled: reason}, {:ok, _at}} when is_binary(reason) ->
        {:noreply, put_flash(socket, :error, reason)}

      {nil, _place} ->
        {:noreply, put_flash(socket, :error, "That section can't go on this page.")}

      {_option, :error} ->
        {:noreply, put_flash(socket, :error, "A section can't go there.")}
    end
  end

  def handle_event("add_section", _params, socket), do: {:noreply, socket}

  # Removing the open section closes it, quietly: it's no surprise. The
  # focus goes to the section that takes its place, or else the one
  # before it. Remove, Up, Down, and Swap sides do only what the open
  # section's header offers (`offered?/3`).
  def handle_event("remove_section", %{"key" => key}, socket) do
    if offered?(socket, :remove, key),
      do: remove_section(socket, key),
      else: {:noreply, socket}
  end

  # A moved section is drawn again where it went, which takes the focus
  # from the button that moved it, so the focus goes back to it, or to the
  # other one when it's gone, as it is at the top or the bottom, and the
  # page scrolls as little as it must to show it.
  def handle_event("move", %{"key" => key, "dir" => dir}, socket) when dir in ~w(up down) do
    if offered?(socket, if(dir == "up", do: :up, else: :down), key),
      do: move(socket, key, dir),
      else: {:noreply, socket}
  end

  def handle_event("swap_columns", %{"key" => key}, socket) do
    if offered?(socket, :swap, key) do
      with_draft(socket, fn _draft, sections ->
        case Map.fetch(sections, key) do
          {:ok, section} -> Pages.swap_columns(section, actor: actor(socket))
          :error -> {:error, :gone}
        end
      end)
    else
      {:noreply, socket}
    end
  end

  def handle_event("commit", _params, socket) do
    pattern = socket.assigns.page.pattern
    result = domain().commit_page(pattern, actor: actor(socket))
    Pages.drain_page_changes(pattern)

    socket =
      case result do
        {:ok, _live} -> put_flash(socket, :info, "Published. Your changes are on the site.")
        {:error, error} -> put_flash(socket, :error, message(error))
      end

    {:noreply, load_page(socket, quiet: true)}
  end

  # Words being typed are put back as they're stored (`words:reset`),
  # even in the field being typed in, which the redraw leaves alone. A
  # section the draft added goes with it, and closes.
  def handle_event("discard", _params, socket) do
    pattern = socket.assigns.page.pattern
    result = domain().discard_page(pattern, actor: actor(socket))
    Pages.drain_page_changes(pattern)

    socket =
      case result do
        :ok -> put_flash(socket, :info, "Discarded. The page is as it was.")
        {:error, error} -> put_flash(socket, :error, message(error))
      end

    # The open section's editor drops a change it held, and why words
    # didn't save.
    if socket.assigns.open,
      do: send_update(SectionEditor, id: "section-editor", discarded: true)

    {:noreply, socket |> load_page(quiet: true) |> push_event("words:reset", %{})}
  end

  # The site's own pages send events of their own, such as a filter's,
  # which the editor draws and does nothing with
  # (`Billboard.Site.page_events/0`). One of the editor's own events
  # (`@handled`) with parameters no clause above takes, or any other
  # event, is a mistake, so it's said, not swallowed.
  @handled ~w(open_section close_section mode palette close_palette add_section
              remove_section move swap_columns commit discard)

  def handle_event(event, params, socket) when event in @handled do
    Logger.warning(
      "The page editor got `#{event}` with parameters it can't use: " <>
        inspect(params, limit: 10, printable_limit: 80)
    )

    {:noreply, socket}
  end

  def handle_event(event, _params, socket) do
    unless event in Billboard.Site.page_events() do
      Logger.warning(
        "The page editor got an event it doesn't know, #{inspect(event, printable_limit: 80)}. " <>
          "If the site's page sends it, add it to `page_events:` in `use Billboard.Site`; " <>
          "otherwise handle it."
      )
    end

    {:noreply, socket}
  end

  defp remove_section(socket, key) do
    keys = Enum.map(socket.assigns.version.sections, & &1.key)

    neighbours =
      case Enum.find_index(keys, &(&1 == key)) do
        nil -> []
        index -> Enum.reject([Enum.at(keys, index + 1), Enum.at(keys, index - 1)], &is_nil/1)
      end

    {result, socket} =
      change(
        socket,
        fn _draft, sections ->
          case Map.fetch(sections, key) do
            {:ok, section} -> domain().destroy_section(section, actor: actor(socket))
            :error -> {:error, :gone}
          end
        end,
        quiet: true
      )

    socket =
      case result do
        {:ok, _removed} ->
          focus(socket, Enum.map(neighbours, &"open-#{&1}") ++ ["page-picker-toggle"])

        :error ->
          socket
      end

    {:noreply, socket}
  end

  defp move(socket, key, dir) do
    {_result, socket} =
      change(socket, fn draft, _sections ->
        case swap(draft.sections, key, if(dir == "up", do: -1, else: 1)) do
          {:ok, order} -> domain().arrange_sections(draft.id, order, actor: actor(socket))
          :unchanged -> :ok
          :error -> {:error, :gone}
        end
      end)

    other = if dir == "up", do: "down", else: "up"

    {:noreply,
     focus(socket, ["section-move-#{dir}", "section-move-#{other}", "section-done"], scroll: true)}
  end

  @impl true
  def handle_info(
        {:page_draft_changed, pattern},
        %{assigns: %{page: %{pattern: pattern}}} = socket
      ) do
    # A change arrives as a burst, one message per row, so read the page
    # once for the lot. Never trust the message itself: it can come from a
    # change that was rolled back.
    Pages.drain_page_changes(pattern)
    {:noreply, load_page(socket)}
  end

  # From a page this editor has since left.
  def handle_info({:page_draft_changed, _pattern}, socket), do: {:noreply, socket}

  # The open section's editor saved it into the draft, perhaps making the
  # draft.
  def handle_info({:section_saved, _key}, socket), do: {:noreply, load_page(socket)}

  # The editor moves the focus to what the page draws for it, once the
  # page is drawn again with it, as a list's new item.
  def handle_info({:editor_focus, focus}, socket),
    do: {:noreply, push_event(socket, "editor:focus", focus)}

  # The editor's change didn't save, for a reason its fields can't show.
  def handle_info({:section_refused, message}, socket),
    do: {:noreply, socket |> put_flash(:error, message) |> load_page()}

  # Runs `fun` on the page's draft, making the draft on the first change
  # (`Pages.change_draft/3`), then reads the page again. A change that
  # fails takes back the draft it made.
  #
  # The change's own notifications are already waiting in the mailbox by
  # the time it returns. They're drained before the reload, so the editor
  # reads the page once, not once more for its own change.
  defp with_draft(socket, fun) do
    {_result, socket} = change(socket, fun)
    {:noreply, socket}
  end

  # `with_draft/2` that says how it went: `{:ok, result}`, with what `fun`
  # returned, or `:error`, with the socket. `opts` go to `load_page/2`.
  defp change(socket, fun, opts \\ []) do
    pattern = socket.assigns.page.pattern
    result = Pages.change_draft(pattern, fun, actor: actor(socket))
    Pages.drain_page_changes(pattern)

    case result do
      {:ok, result} ->
        {{:ok, result}, load_page(socket, opts)}

      {:error, error} ->
        {:error, socket |> put_flash(:error, message(error)) |> load_page(opts)}
    end
  end

  # A new section holds its component's placeholder content. It is made at
  # the end, then moved to `at` among the draft's top-level sections, in
  # the same transaction (`with_draft/2`'s), so it can't be left at the
  # end.
  defp add_section(socket, draft, type, at) do
    with {:ok, section} <- add_section(socket, draft, type),
         :ok <- put_at(draft, section, at, actor: actor(socket)),
         do: {:ok, section}
  end

  defp put_at(draft, section, at, opts) do
    ids = Enum.map(draft.sections, & &1.id)

    if at >= length(ids),
      do: :ok,
      else: domain().arrange_sections(draft.id, List.insert_at(ids, at, section.id), opts)
  end

  # Two columns arrive holding two Details sections, or, on a site
  # without Details, two of the first component that fits in a column, as
  # the palette draws them (`Palette.column_type/0`), since an empty pair
  # breaks the rules and nothing else would fill it.
  defp add_section(socket, draft, :columns) do
    opts = [actor: actor(socket)]
    column = Palette.column_type()

    # `with_draft/2`'s transaction takes back the pair if either half fails.
    with {:ok, columns} <- create_section(draft.id, :columns, %{}, nil, opts),
         {:ok, _left} <- create_section(draft.id, column, nil, columns.id, opts),
         {:ok, _right} <- create_section(draft.id, column, nil, columns.id, opts) do
      {:ok, columns}
    end
  end

  defp add_section(socket, draft, :shared) do
    case Palette.unplaced(socket.assigns.library, draft.sections) do
      [key | _] -> create_section(draft.id, :shared, %{key: key}, nil, actor: actor(socket))
      [] -> {:error, :nothing_to_share}
    end
  end

  defp add_section(socket, draft, type),
    do: create_section(draft.id, type, nil, nil, actor: actor(socket))

  defp create_section(version_id, type, attrs, parent_id, opts) do
    attrs = Map.merge(Catalogue.placeholder(type), attrs || %{})

    with {:ok, value} <- Billboard.Component.build(type, attrs) do
      domain().create_section(
        %{
          version_id: version_id,
          parent_id: parent_id,
          content: %Ash.Union{type: type, value: value}
        },
        opts
      )
    end
  end

  # The draft's top-level section ids, with `key`'s section swapped with
  # the neighbour `by` places away.
  defp swap(sections, key, by) do
    keys = Enum.map(sections, & &1.key)
    ids = Map.new(sections, &{&1.key, &1.id})

    case Enum.find_index(keys, &(&1 == key)) do
      nil ->
        :error

      index when index + by < 0 or index + by >= length(keys) ->
        :unchanged

      index ->
        other = index + by

        order =
          keys
          |> List.replace_at(index, Enum.at(keys, other))
          |> List.replace_at(other, key)

        {:ok, Enum.map(order, &Map.fetch!(ids, &1))}
    end
  end

  # Reads the page again, with the data its sections draw for the page's
  # sample context. An open section that has gone was removed by someone
  # else, unless `quiet: true` says this editor's own change took it, as a
  # removal or a discard does.
  defp load_page(socket, opts \\ []) do
    %{page: page, context: context} = socket.assigns
    actor_opts = [actor: actor(socket)]

    {:ok, draft} = Pages.draft_for(page.pattern, actor_opts)
    version = draft || Pages.page_for(page.pattern)
    library_version = Pages.page_for(nil)
    library = library_version.sections

    issues =
      Rules.check(page, version.sections, Map.new(library, &{&1.key, &1})) ++
        Filler.warnings(version.sections)

    socket
    |> assign(draft: draft, version: version, library: library, library_version: library_version)
    |> assign(:data, Resolver.resolve(version, context))
    |> assign(:current_path, Context.path(page, context))
    |> assign(issues: issues, errors: Enum.filter(issues, &(&1.level == :error)))
    |> assign(:palette, Palette.options(page, version.sections, library, socket.assigns.glyphs))
    |> assign(:drafts, MapSet.new(domain().list_drafts!(actor_opts), & &1.page.pattern))
    |> keep_open(Keyword.get(opts, :quiet, false))
    |> keep_palette()
    |> put_uses()
  end

  # The pages that place each library section, by its key, which the open
  # section's header says when it's a Shared section, or in the library.
  defp put_uses(%{assigns: %{page: page, version: version, open: open}} = socket) do
    open_type =
      Enum.find_value(version.sections, fn section ->
        Enum.find_value([section | section.children], &(&1.key == open && &1.content.type))
      end)

    if page.kind == :library or open_type == :shared,
      do: assign(socket, :shared_uses, shared_uses(page, version)),
      else: assign(socket, :shared_uses, %{})
  end

  # This page as it's being edited, and the others as visitors see them.
  defp shared_uses(page, version) do
    for other <- Directory.pages(),
        other.pattern != nil,
        sections =
          if(other.pattern == page.pattern,
            do: version.sections,
            else: Pages.page_for(other.pattern).sections
          ),
        section <- Enum.flat_map(sections, &[&1 | &1.children]),
        section.content.type == :shared,
        reduce: %{} do
      uses -> Map.update(uses, section.content.value.key, [other], &Enum.uniq(&1 ++ [other]))
    end
  end

  # The palette stays open where it was while that place is still on the
  # page, as when another admin's change arrives.
  defp keep_palette(%{assigns: %{adding_at: nil}} = socket), do: socket

  defp keep_palette(socket) do
    if socket.assigns.palette != [] and
         socket.assigns.adding_at in Palette.places(socket.assigns.version.sections),
       do: socket,
       else: assign(socket, :adding_at, nil)
  end

  # The place `at` names (`Palette.places/1`), if the page has it and can
  # add a section there.
  defp place(socket, at) do
    at =
      case at do
        at when is_integer(at) -> {at, ""}
        at when is_binary(at) -> Integer.parse(at)
        _other -> :error
      end

    case at do
      {at, ""} ->
        if socket.assigns.palette != [] and at in Palette.places(socket.assigns.version.sections),
          do: {:ok, at},
          else: :error

      _not_a_place ->
        :error
    end
  end

  # Closes the palette, handing the focus back to the place it opened at.
  defp close_palette(%{assigns: %{adding_at: nil}} = socket), do: socket

  defp close_palette(socket) do
    at = socket.assigns.adding_at
    socket |> assign(:adding_at, nil) |> focus(["section-add-at-#{at}", "page-picker-toggle"])
  end

  # Opens a section just added, with the focus in its first words, if it
  # has any, selected to be typed over, and otherwise in its header.
  defp open_new(socket, key) do
    socket
    |> assign(:open, key)
    |> put_uses()
    |> forget_open_in_url()
    |> push_event("editor:focus", %{
      words: key,
      ids: ["section-controls"],
      select: true,
      scroll: true
    })
  end

  # The section to open for the one just added at `key`: its first column,
  # for Two columns, and otherwise itself.
  defp section_to_open(socket, key) do
    case Enum.find(socket.assigns.version.sections, &(&1.key == key)) do
      %{content: %{type: :columns}, children: [first | _]} -> first.key
      _other -> key
    end
  end

  defp keep_open(%{assigns: %{open: nil}} = socket, _quiet?), do: socket

  defp keep_open(socket, quiet?) do
    cond do
      socket.assigns.open in section_keys(socket.assigns.version) ->
        socket

      quiet? ->
        assign(socket, :open, nil)

      true ->
        socket |> assign(:open, nil) |> put_flash(:info, "Someone else removed this section.")
    end
  end

  # Opens the section `key` names, if it's one of the page's, at the top
  # level or in Two columns, with the focus on the first of `at` that's
  # drawn, or its header. Anything else is ignored.
  defp open_section(socket, key, at \\ [])

  defp open_section(socket, key, at) when is_binary(key) do
    if key in section_keys(socket.assigns.version),
      do:
        socket
        |> assign(open: key, adding_at: nil)
        |> put_uses()
        |> focus(at ++ ["section-controls"]),
      else: socket
  end

  defp open_section(socket, _key, _at), do: socket

  # Scrolls the open section's top to just under the bar (`.EditorBar`).
  defp reveal(%{assigns: %{open: nil}} = socket), do: socket
  defp reveal(socket), do: push_event(socket, "editor:reveal", %{key: socket.assigns.open})

  # Moves the focus to the first of the elements `ids` names that's on the
  # page once it's drawn (`.EditorBar`), and with `scroll: true` brings it
  # into view. Pushed events arrive after the page is drawn again.
  defp focus(socket, ids, opts \\ []),
    do: push_event(socket, "editor:focus", %{ids: ids, scroll: Keyword.get(opts, :scroll, false)})

  # The address, once the section it opened isn't the open one.
  defp forget_open_in_url(%{assigns: %{open_in_url?: true}} = socket) do
    socket
    |> assign(:open_in_url?, false)
    |> push_patch(to: editor_path(socket, socket.assigns.page.pattern), replace: true)
  end

  defp forget_open_in_url(socket), do: socket

  defp section_keys(version),
    do: Enum.flat_map(version.sections, &[&1.key | Enum.map(&1.children, fn c -> c.key end)])

  # Subscribes to `page`'s draft, leaving the page the editor had open.
  defp follow(%{assigns: %{page: page}} = socket, page), do: socket

  defp follow(socket, page) do
    if connected?(socket) do
      if old = socket.assigns.page, do: Pages.unsubscribe_page(old.pattern)
      Pages.subscribe_page(page.pattern)
    end

    socket
  end

  defp page_from_param(pattern) when is_binary(pattern) do
    if pattern == Editor.library_param(),
      do: Directory.fetch!(nil),
      else: Directory.fetch(pattern) || home()
  end

  defp page_from_param(_pattern), do: home()

  defp home, do: Directory.fetch!("/")

  # A page's DOM id in the picker: the pattern's words, so
  # `/services/:slug` is `page-tab-services-slug`, and `/` is
  # `page-tab-home`.
  defp page_tab_id(nil), do: "page-tab-#{Editor.library_param()}"
  defp page_tab_id("/"), do: "page-tab-home"

  defp page_tab_id(pattern) do
    slug =
      pattern
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    "page-tab-" <> slug
  end

  # The editor's address for the page at route `pattern` (`nil` for the
  # library), with `open: key` the section it opens, as the router mounts
  # it (`Billboard.Editor.path/3`).
  defp editor_path(socket, pattern, opts \\ []), do: Editor.path(socket.router, pattern, opts)

  defp domain, do: Billboard.Site.domain!()

  defp palette_options(socket), do: Enum.flat_map(socket.assigns.palette, &elem(&1, 1))

  defp actor(socket), do: socket.assigns.current_scope.user

  ## Rendering

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        ctx: page_ctx(assigns),
        page_issues: Enum.filter(assigns.issues, &is_nil(&1.key))
      )

    ~H"""
    <.editor_bar
      back={@back}
      editor_path={@editor_path}
      pages={@pages}
      page={@page}
      drafts={@drafts}
      draft={@draft}
      errors={@errors}
      mode={@mode}
    />

    <div
      :if={@mode == :edit and @page_issues != []}
      id="page-issues"
      role="alert"
      class="border-b border-bb-edit-line bg-bb-edit-ground"
    >
      <ul class="bb-wrap bb-edit-type-small grid gap-1 py-3">
        <li
          :for={issue <- @page_issues}
          data-level={issue.level}
          class={if(issue.level == :error, do: "text-bb-edit-error", else: "text-bb-edit-soft")}
        >
          {sentence(issue.message)}
        </li>
      </ul>
    </div>

    <div
      id="edit-canvas"
      phx-hook="EditCanvas"
      data-mode={@mode}
      data-has-open={@open && "true"}
    >
      <%!-- The page draws no messages while editing, so it's handed none:
      a message would otherwise redraw the hero and every section. The
      editor's own are drawn after it. --%>
      <Sections.page
        version={@version}
        data={@data}
        library={@library_version}
        ctx={@ctx}
        flash={%{}}
        site={@site}
        current_path={@current_path}
        heading={if(@page.kind == :library, do: @page.label)}
        lede={
          if(@page.kind == :library,
            do: "Sections you can place on several pages. Changes here publish on their own."
          )
        }
        editing
      />
      <div data-editor-ui class="bb-editor-flash">
        <Components.flash_group flash={@flash} />
      </div>
    </div>
    """
  end

  # What the page's sections are drawn with. Editing, the open section,
  # each section's worst issue, and what the open section's editor needs;
  # viewing as a visitor, nothing of the editor's.
  defp page_ctx(%{mode: :view} = assigns), do: %{context: assigns.context, state: %{}}

  defp page_ctx(assigns) do
    %{
      context: assigns.context,
      state: %{},
      edit: %{
        open: assigns.open,
        issues: issue_levels(assigns.issues),
        editor: %{
          page: assigns.page,
          actor: assigns.current_scope.user,
          choices: assigns.choices,
          library: assigns.library,
          issues: assigns.issues,
          moves: moves(assigns),
          parent: parent_key(assigns),
          uses: assigns.shared_uses,
          editor_path: assigns.editor_path
        },
        add: add_ctx(assigns)
      }
    }
  end

  # Where sections can be added (`Palette.gap/1`): nowhere on a fixed page.
  defp add_ctx(%{palette: []}), do: nil

  defp add_ctx(assigns) do
    %{
      at: assigns.adding_at,
      palette: assigns.palette,
      library: Map.new(assigns.library, &{&1.key, &1})
    }
  end

  # Which of Remove, Up, and Down the open section has. The hero stays
  # first, so it never moves and nothing moves above it, and it never
  # goes. A fixed page's sections don't move or go at all, and nor does a
  # section in Two columns, which needs both.
  defp moves(%{open: nil}), do: %{}
  defp moves(%{open: key} = assigns), do: moves(assigns, key)

  defp moves(%{version: version, page: page}, key) do
    sections = version.sections
    fixed? = is_list(page.fixed)

    case Enum.find_index(sections, &(&1.key == key)) do
      nil ->
        %{}

      index ->
        %{
          up: movable?(sections, index, -1, fixed?),
          down: movable?(sections, index, 1, fixed?),
          remove: removable?(Enum.at(sections, index), fixed?)
        }
    end
  end

  # Whether the open section's header offers `action` (`:remove`, `:up`,
  # `:down`, or `:swap`, Two columns' Swap sides) for the section `key`
  # names, were it open (`moves/2`), so an event can't do what the header
  # wouldn't. View as visitor offers none. A key the page hasn't got goes
  # ahead, for the change to say the section has gone: someone else may
  # have just removed it.
  defp offered?(%{assigns: %{mode: :view}}, _action, _key), do: false

  defp offered?(%{assigns: assigns}, action, key) do
    sections = Enum.flat_map(assigns.version.sections, &[&1 | &1.children])

    case Enum.find(sections, &(&1.key == key)) do
      nil ->
        true

      %{content: %{type: type}} when action == :swap ->
        type == :columns and not is_list(assigns.page.fixed)

      _section ->
        Map.get(moves(assigns, key), action, false)
    end
  end

  # The Two columns holding the open section, by its key, if it's a
  # column's, for its header to go up to.
  defp parent_key(%{open: nil}), do: nil

  defp parent_key(%{open: key, version: version}),
    do:
      Enum.find_value(
        version.sections,
        &(Enum.any?(&1.children, fn c -> c.key == key end) && &1.key)
      )

  defp movable?(_sections, _index, _by, true = _fixed?), do: false

  defp movable?(sections, index, by, _fixed?) do
    target = index + by

    target >= 0 and target < length(sections) and
      not hero?(Enum.at(sections, index)) and not hero?(Enum.at(sections, target))
  end

  defp removable?(_section, true = _fixed?), do: false
  defp removable?(section, _fixed?), do: not hero?(section)

  defp hero?(%{content: %{type: :hero}}), do: true
  defp hero?(_section), do: false

  # The worst issue the rules have with each section, by key.
  defp issue_levels(issues) do
    for %{key: key, level: level} <- issues, key != nil, reduce: %{} do
      levels -> Map.update(levels, key, level, &if(&1 == :error, do: :error, else: level))
    end
  end

  attr :pages, :list, required: true
  attr :page, :map, required: true
  attr :drafts, :any, required: true, doc: "the patterns of the pages with drafts"
  attr :draft, :map, required: true, doc: "the page's draft, or nil"
  attr :errors, :list, required: true
  attr :mode, :atom, values: [:edit, :view], required: true
  attr :back, :any, required: true, doc: "where the back link goes, as `{words, path}`"

  attr :editor_path, {:fun, 2},
    required: true,
    doc: "the editor's address for a page, and options"

  # The slim bar above the page: back to the admin, the page picker, what
  # the page's changes come to, Edit or View as visitor, and Discard and
  # Publish. Discard sits left of Publish: the more destructive action is
  # furthest from the bottom-right. Both ask first, Discard because it
  # can't be undone, and Publish because it changes what visitors see.
  # Either one disables both, taking the focus with it, so they hand it to
  # the page picker. On phones, where the bar wraps, its buttons are
  # narrower, View as visitor says only "View", and they fit on one row.
  defp editor_bar(assigns) do
    ~H"""
    <div
      id="editor-bar"
      phx-hook=".EditorBar"
      class="sticky top-0 z-50 flex flex-wrap items-center gap-x-5 gap-y-2 border-b border-bb-edit-line bg-bb-edit-ground px-4 py-2 text-bb-edit-ink md:px-6"
    >
      <.link
        id="editor-back"
        navigate={elem(@back, 1)}
        class="bb-edit-type-small flex min-h-11 items-center gap-1 text-bb-edit-soft transition-colors duration-[var(--bb-edit-duration)] ease-bb-edit hover:text-bb-edit-ink"
      >
        <span aria-hidden="true">‹</span> {elem(@back, 0)}
      </.link>

      <.page_picker pages={@pages} page={@page} drafts={@drafts} editor_path={@editor_path} />

      <div class="flex min-w-0 items-center gap-2">
        <span
          aria-hidden="true"
          class={[
            "size-2 shrink-0 rounded-full",
            cond do
              @errors != [] -> "bg-bb-edit-error"
              @draft -> "bg-bb-edit-warn"
              true -> "bg-bb-edit-line"
            end
          ]}
        >
        </span>
        <p
          id="draft-status"
          role="status"
          aria-live="polite"
          class="bb-edit-type-small text-bb-edit-soft"
        >
          <%= cond do %>
            <% @errors != [] -> %>
              <span id="commit-blockers">{fixes(@errors)} before you publish.</span>
            <% @draft -> %>
              Your changes aren't on the site yet.
            <% true -> %>
              Click any section to change it.
          <% end %>
        </p>
        <.saved_at :if={@draft} draft={@draft} />
      </div>

      <div class="flex flex-wrap items-center gap-2 sm:ml-auto sm:gap-3">
        <div role="group" aria-label="Mode" class="flex border border-bb-edit-line">
          <button
            :for={
              {mode, label, short} <- [{:edit, "Edit", "Edit"}, {:view, "View as visitor", "View"}]
            }
            id={"mode-#{mode}"}
            type="button"
            phx-click="mode"
            phx-value-mode={mode}
            aria-label={label}
            aria-pressed={to_string(@mode == mode)}
            class={[
              "bb-edit-type-button min-h-11 cursor-pointer px-3 max-sm:px-2.5",
              "transition-colors duration-[var(--bb-edit-duration)] ease-bb-edit",
              if(@mode == mode,
                do: "bg-bb-edit-ink text-bb-edit-paper",
                else: "text-bb-edit-soft hover:bg-bb-edit-line/40 hover:text-bb-edit-ink"
              )
            ]}
          >
            <span class="max-sm:hidden">{label}</span>
            <span class="sm:hidden" aria-hidden="true">{short}</span>
          </button>
        </div>
        <Components.button
          id="discard-changes"
          type="button"
          class="max-sm:px-4"
          variant="secondary"
          disabled={is_nil(@draft)}
          phx-click={JS.push("discard") |> JS.focus(to: "#page-picker-toggle")}
          data-confirm="Discard your changes to this page? This can't be undone."
        >
          Discard
        </Components.button>
        <Components.button
          id="commit-changes"
          type="button"
          class="max-sm:px-4"
          phx-click={JS.push("commit") |> JS.focus(to: "#page-picker-toggle")}
          aria-describedby={@errors != [] && "commit-blockers"}
          disabled={is_nil(@draft) or @errors != []}
          data-confirm="Put your changes on the site? They replace the live page."
        >
          Publish
        </Components.button>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".EditorBar">
        // Keeps the bar's height in --bb-edit-bar-height, for the open
        // section's controls to stick under it as it wraps; and moves the
        // focus where the editor says (`editor:focus`), to the first of the
        // elements it names that's on the page, scrolling only when asked.
        // Named by its key (`words`), a section takes the focus into its
        // first words that can be typed into, if it has any, or, with
        // `at` (a dashed path, `points-2`), into the first words there.
        export default {
          mounted() {
            const root = document.documentElement.style
            this.observer = new ResizeObserver(() =>
              root.setProperty("--bb-edit-bar-height", `${this.el.offsetHeight}px`)
            )
            this.observer.observe(this.el)

            // An element that can't take the focus itself, such as a
            // button's mark in the open section, hands it to the first
            // thing in it that can.
            const focusable =
              "a[href], button:not([disabled]), input, select, textarea, summary, [tabindex], [contenteditable]"
            // With `select`, words in a field are selected, to be typed over.
            // Words' ids are `Billboard.Sections.Words.id/2`'s.
            this.handleEvent("editor:focus", ({ids, scroll, select, words, at}) => {
              const within = at ? `[id^="${CSS.escape(`words-${words}-${at}-`)}"]` : ""
              let el =
                words &&
                document.querySelector(
                  `[data-edit-section="${CSS.escape(words)}"] .bb-inline-words[contenteditable]${within}`
                )
              el = el || ids.map(id => document.getElementById(id)).find(Boolean)
              if (el && !el.matches(focusable)) el = el.querySelector(focusable) || el
              el?.focus({preventScroll: true})
              if (select && typeof el?.select === "function") el.select()
              else if (select && el?.isContentEditable) window.getSelection().selectAllChildren(el)
              if (scroll) el?.scrollIntoView({block: "nearest"})
            })

            // Brings a section (`editor:reveal`) to just under the bar.
            this.handleEvent("editor:reveal", ({key}) => {
              const section = document.querySelector(`[data-edit-section="${CSS.escape(key)}"]`)
              if (!section) return
              const top = section.getBoundingClientRect().top + window.scrollY
              window.scrollTo({top: top - this.el.offsetHeight})
            })
          },
          destroyed() {
            this.observer.disconnect()
            document.documentElement.style.removeProperty("--bb-edit-bar-height")
          }
        }
      </script>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".LocalTime">
        // Shows a time in the admin's own time zone ("14:02") in place of
        // the server's UTC. A new time is a new element (its id carries
        // the time), so this runs again for each save.
        export default {
          mounted() {
            const at = new Date(this.el.getAttribute("datetime"))
            if (isNaN(at)) return
            this.el.textContent =
              at.toLocaleTimeString([], {hour: "2-digit", minute: "2-digit", hourCycle: "h23"})
          }
        }
      </script>
    </div>
    """
  end

  attr :draft, :map, required: true

  defp saved_at(assigns) do
    assigns = assign(assigns, :at, last_saved(assigns.draft))

    ~H"""
    <span class="bb-edit-type-small whitespace-nowrap text-bb-edit-soft">
      Saved <time
        id={"draft-saved-at-#{DateTime.to_unix(@at, :microsecond)}"}
        datetime={@at |> DateTime.truncate(:second) |> DateTime.to_iso8601()}
        phx-hook=".LocalTime"
        phx-update="ignore"
      >{Calendar.strftime(@at, "%H:%M")} UTC</time>.
    </span>
    """
  end

  attr :pages, :list, required: true
  attr :page, :map, required: true
  attr :drafts, :any, required: true
  attr :editor_path, {:fun, 2}, required: true

  # Every page, with a dot for those with changes, and the library
  # last, after a rule. A pick moves the editor to that page, which closes
  # the menu: LiveView puts its `open` back as the server drew it.
  defp page_picker(assigns) do
    ~H"""
    <details
      id="page-picker"
      class="relative"
      phx-click-away={JS.remove_attribute("open", to: "#page-picker")}
    >
      <summary
        id="page-picker-toggle"
        class="bb-edit-type-button flex min-h-11 cursor-pointer list-none items-center gap-2 [&::-webkit-details-marker]:hidden"
      >
        {@page.label}
        <span
          :if={MapSet.member?(@drafts, @page.pattern)}
          class="size-1.5 rounded-full bg-bb-edit-warn"
          aria-hidden="true"
        >
        </span>
        <Components.icon name="hero-chevron-down-mini" class="size-4 text-bb-edit-soft" />
      </summary>
      <nav
        aria-label="Pages"
        class="absolute top-full left-0 z-50 mt-1 min-w-64 border border-bb-edit-line bg-bb-edit-ground py-2"
      >
        <ol id="page-list">
          <li
            :for={page <- @pages}
            class={[page.kind == :library && "mt-2 border-t border-bb-edit-line pt-2"]}
          >
            <.link
              id={page_tab_id(page.pattern)}
              patch={@editor_path.(page.pattern, [])}
              aria-current={page.pattern == @page.pattern && "page"}
              data-draft={MapSet.member?(@drafts, page.pattern)}
              class={[
                "bb-edit-type-small flex min-h-11 items-center gap-2 whitespace-nowrap border-l-2 px-4",
                "transition-colors duration-[var(--bb-edit-duration)] ease-bb-edit",
                if(page.pattern == @page.pattern,
                  do: "border-bb-edit-ink text-bb-edit-ink",
                  else:
                    "border-transparent text-bb-edit-soft hover:bg-bb-edit-line/40 hover:text-bb-edit-ink"
                )
              ]}
            >
              {page.label}
              <span
                :if={MapSet.member?(@drafts, page.pattern)}
                class="size-1.5 rounded-full bg-bb-edit-warn"
                aria-hidden="true"
              >
              </span>
              <span :if={MapSet.member?(@drafts, page.pattern)} class="sr-only">
                (has changes)
              </span>
            </.link>
          </li>
        </ol>
      </nav>
    </details>
    """
  end

  defp fixes([_one]), do: "1 thing needs fixing"
  defp fixes(errors), do: "#{length(errors)} things need fixing"

  # When the draft last changed: the latest of its own time and its
  # sections'. A section's removal leaves no trace, so it doesn't count.
  defp last_saved(draft) do
    draft.sections
    |> Enum.flat_map(&[&1 | &1.children])
    |> Enum.map(& &1.updated_at)
    |> Enum.concat([draft.updated_at])
    |> Enum.max(DateTime)
  end
end
