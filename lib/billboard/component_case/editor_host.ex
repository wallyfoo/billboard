defmodule Billboard.ComponentCase.EditorHost do
  @moduledoc false
  # The page editor's canvas for `Billboard.ComponentCase`: one page,
  # drawn in the site's layout with one section open, its words in place
  # and its section editor beside it, as `Billboard.EditorLive` draws
  # them. Mounted with `live_isolated/3` and the session
  # `Billboard.ComponentCase`'s open checks build. Nothing is saved: it
  # handles no events.
  use Phoenix.LiveView

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     assign(socket,
       version: session["version"],
       key: session["key"],
       data: session["data"],
       library: session["library"],
       library_sections: library_sections(session["library"]),
       context: session["context"],
       page: Billboard.Directory.fetch!(session["path"]),
       site: Billboard.Layout.site(),
       choices: Billboard.Context.choices_for(Billboard.Sections.EditorFields.choice_names())
     )}
  end

  # The library's sections, as the page editor hands them to the section
  # editor: the given library version's, or the live library's.
  defp library_sections(nil), do: Billboard.Pages.page_for(nil).sections
  defp library_sections(library), do: library.sections

  @impl true
  def render(assigns) do
    ~H"""
    <div id="edit-canvas">
      <Billboard.Sections.page
        version={@version}
        data={@data}
        library={@library}
        site={@site}
        flash={%{}}
        current_path={@page.pattern}
        editing
        ctx={ctx(assigns)}
      />
    </div>
    """
  end

  # The ctx `Billboard.EditorLive` builds for its canvas (its private
  # `page_ctx/1`), for one open section, no admin, and no palette: every
  # key it gives, with these values. If `page_ctx/1` gains a key, give it
  # here too.
  defp ctx(assigns) do
    %{
      context: assigns.context,
      state: %{},
      edit: %{
        open: assigns.key,
        issues: %{},
        add: nil,
        editor: %{
          page: assigns.page,
          actor: nil,
          choices: assigns.choices,
          library: assigns.library_sections,
          issues: [],
          moves: %{},
          parent: nil,
          uses: %{},
          editor_path: fn _pattern, _opts -> "#" end
        }
      }
    }
  end
end
