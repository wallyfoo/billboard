defmodule Billboard.Test.SectionEditorHost do
  @moduledoc """
  A LiveView for `Billboard.EditorLive.SectionEditor`'s tests, which draws
  the editor for one section of a page on the shop, as the page editor
  will. It reads the page again when the editor saves, as the page editor
  does, so the editor is handed the draft's section after a first change,
  and shows a refusal the editor sends up in `#section-refused`. `"open"`
  hands it another section, by key, and `"issues"` the issues the page
  editor would hand it. It moves the focus where the editor asks
  (`{:editor_focus, payload}`), as the page editor does. A column is
  handed its Two columns' key as `parent`, as the page editor finds it.
  The editor's addresses are the editor's at `/pages`.

  Mounted with `live_isolated/3` and a session of `"pattern"` (nil for the
  library), `"key"`, and `"actor"`.
  """
  use Phoenix.LiveView

  alias Billboard.{Directory, Pages}
  alias Billboard.EditorLive.SectionEditor

  @impl true
  def mount(_params, %{"pattern" => pattern, "key" => key, "actor" => actor}, socket) do
    {:ok,
     socket
     |> assign(page: Directory.fetch!(pattern), key: key, actor: actor, refused: nil)
     |> assign(:issues, [])
     |> assign(
       :choices,
       Billboard.Context.choices_for(Billboard.Sections.EditorFields.choice_names())
     )
     |> load()}
  end

  @impl true
  def handle_event("open", %{"key" => key}, socket),
    do: {:noreply, socket |> assign(:key, key) |> load()}

  def handle_event("issues", %{"issues" => issues}, socket) do
    issues =
      for %{"level" => level, "message" => message} <- issues,
          do: %{level: if(level == "error", do: :error, else: :warning), message: message}

    {:noreply, assign(socket, :issues, Enum.map(issues, &Map.put(&1, :key, socket.assigns.key)))}
  end

  @impl true
  def handle_info({:section_saved, _key}, socket), do: {:noreply, load(socket)}

  def handle_info({:editor_focus, focus}, socket),
    do: {:noreply, push_event(socket, "editor:focus", focus)}

  def handle_info({:section_refused, message}, socket),
    do: {:noreply, socket |> assign(:refused, message) |> load()}

  defp load(socket) do
    %{page: page, key: key, actor: actor} = socket.assigns
    {:ok, draft} = Pages.draft_for(page.pattern, actor: actor)
    version = draft || Pages.page_for(page.pattern)

    section =
      version.sections
      |> Enum.flat_map(&[&1 | &1.children])
      |> Enum.find(&(&1.key == key))

    parent =
      Enum.find_value(
        version.sections,
        &(Enum.any?(&1.children, fn c -> c.key == key end) && &1.key)
      )

    assign(socket, section: section, parent: parent, library: Pages.page_for(nil).sections)
  end

  # The editor's address for a page (`nil` for the library), as the page
  # editor gives it.
  defp editor_path(pattern, opts),
    do: "/pages?" <> URI.encode_query(Keyword.take(opts, [:open]) ++ [page: pattern || "shared"])

  @impl true
  def render(assigns) do
    ~H"""
    <div id="host">
      <p :if={@refused} id="section-refused">{@refused}</p>
      <.live_component
        :if={@section}
        module={SectionEditor}
        id="section-editor"
        section={@section}
        page={@page}
        actor={@actor}
        choices={@choices}
        library={@library}
        issues={@issues}
        parent={@parent}
        editor_path={&editor_path/2}
      />
    </div>
    """
  end
end
