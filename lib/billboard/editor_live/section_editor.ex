defmodule Billboard.EditorLive.SectionEditor do
  @moduledoc """
  The open section's editor in the page editor (`Billboard.EditorLive`):
  there is one at a time, for the section the admin clicked. Its words
  are typed in place on the page (`Billboard.Sections.Words`), and arrive
  here as `edit_words`; everything else, such as its layout, its
  settings, and its lists, is changed from its controls, drawn from the
  component's `editor` section. Its root is `#section-editor`, with the
  section's key in `data-section`, which the words' hook checks before it
  sends.

  Its controls header, which sticks under the editor's bar while the
  section scrolls by, holds everything but the words: the section's
  name; Remove; its layouts, as small drawings, where the site offers
  more than one; its ground, where the site offers it a choice of
  surfaces (`Billboard.Surfaces`); its settings, drawn small
  (`EditorFields.setting/1`), as the ground is, each select with only
  the options the site offers (`EditorFields.narrowed/1`) and none left
  with one; a way to add a list's items, and a heading a section can do
  without; More, for words a visitor sees only now and then and the
  section's link name; Up and Down; and Done. Remove, Up, Down, and Done
  go to the page editor, which says which of them the section has
  (`moves`). A fixed page's sections have none of Remove, Up, and Down,
  and say so. Two columns swap sides from their header (to the page
  editor too), and a column's header starts with a way up to its Two
  columns (`parent`, the pair's key). Under it, a strip says what's
  wrong: the rules' issues with the section and its filler (`issues`,
  from the page editor), a control's change the section turned down, and
  words that didn't save.

  A Shared section's words and settings are its library section's, which
  is edited in the library, so its header has none of them: it says
  which pages share it (`uses`, from the page editor), swaps it for
  another library section, and links to the library with it open. In the
  library, a section's header says which pages place it. Only the page
  editor knows the router, so it hands the editor `editor_path`, a
  function of a page's pattern (`nil` for the library) and options, such
  as `open:`, that gives the editor's address for it
  (`Billboard.Editor.path/3`), which the link to the library uses.

  The rest is changed where it's drawn, by controls the renderers draw in
  the open section, which send their events here (`#section-editor`): a
  list's items are removed and moved from their own tools, and a
  detail's scope and a card's ground set there (`edit_part`); a button,
  an action or a point's link, opens a popover under the header
  (`edit_action`), which changes where it goes, how it looks, and its
  words, or takes it away, and a new one is added after the others
  (`add_button`); and a photograph is put in, described (in a popover
  too), and taken away from tools over it. A photograph saves once it
  has arrived.

  The editor shows the live (or starter) section until the page has a
  draft, and the draft's section after that. It knows the section by its
  key, which a draft's sections keep, so it lives through the switch from
  one to the other. Handed another section, it edits that one instead.

  Every change saves as it is made, always into the draft:

    1. The change is tried on the form of the open section. If the
       section turns it down, the editor saves nothing, so a bad first
       change makes no draft, and says why. A control's change is held
       in the form, with why. Words typed in place aren't: the hook is
       told why (`words:refused`), keeps what was typed, and the reason
       waits in `refused_words`, by path, until those words save. Words
       held back only by a control's change (`waiting_words`) go again
       once a change saves (`words:retry`).
    2. Otherwise `Billboard.Pages.change_draft/3` makes the page's
       draft if this is its first change, and the same change is made
       to the draft's section, found by key, and saved.
    3. The editor takes the saved section and tells the page editor
       (`{:section_saved, key}`), which reads the page again.

  A change is a function of a form, so words typed in place, a list's
  add, remove, and move, a part's add and remove, and the variant buttons
  all take the same path. A control's change the section turned down
  stays in the form until it's put right, and every later change waits
  for it. Each field's words save on their own, whatever another field
  holds: no rule of a section ties two words fields together.

  Only what the editor offers is saved (`allowed/4`): the anchor, the
  surface where the header offers a choice of them, and the content
  fields its specs name, so a field it doesn't offer, such as a
  hero's `bind`, can't be changed by a forged event. Words typed in place
  reach only the words fields the specs name (`EditorFields.words/2`), in
  parts and list items the section has.

  Saves are last-writer-wins, field by field: a change sends every field
  the editor's form holds, so an editor that hasn't yet been handed
  another admin's save to the same section writes its own values back
  over theirs. The page editor hands the editor the section again on
  every change to the page's draft, which keeps that window short.

  A removed photograph's file stays: the live page and the draft share it.
  """
  use Phoenix.LiveComponent

  alias Billboard.{Catalogue, Pages, Surfaces, Uploads}
  alias Billboard.Editor.Components
  alias Billboard.Sections.{EditorFields, Parts, Words}
  alias Phoenix.LiveView.JS

  import Billboard.EditorLive.Messages,
    only: [and_list: 1, message: 1, plain: 1, sentence: 1]

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(shown: nil, saved_at: nil, picked: [], photo_params: nil, photo_error: nil)
     |> assign(refused_words: %{}, waiting_words: MapSet.new())
     |> assign(issues: [], moves: %{}, uses: %{}, parent: nil, popover: nil)
     |> allow_upload(:photo,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 15_000_000,
       auto_upload: true,
       progress: &photo_progress/3
     )}
  end

  # Discard put the page back as it was (the page editor's `discarded`):
  # the form is made afresh, without a change it held, and why words
  # didn't save goes with it, as the hook's `words:reset` puts the words
  # back on the page.
  @impl true
  def update(%{discarded: true}, socket) do
    {:ok,
     socket
     |> assign(photo_error: nil, refused_words: %{}, waiting_words: MapSet.new(), popover: nil)
     |> present_section(socket.assigns.section)}
  end

  # The page editor hands the editor its section whenever it reads the
  # page. A section that hasn't changed keeps its form, and what it holds,
  # such as a change it turned down. One that has, as when another admin
  # saved it, is taken afresh, without the change, so words that waited
  # on it go again. Another section starts afresh, with nothing of the
  # last one's, not even a photograph on its way.
  def update(assigns, socket) do
    before = socket.assigns[:section]
    socket = assign(socket, assigns)
    section = socket.assigns.section

    cond do
      before && before.key != section.key ->
        {:ok, socket |> forget_last_section() |> present_section(section)}

      socket.assigns.shown == signature(section) ->
        {:ok, socket}

      true ->
        {:ok, socket |> present_section(section) |> retry_words()}
    end
  end

  defp forget_last_section(socket) do
    socket.assigns.uploads.photo.entries
    |> Enum.reduce(socket, &cancel_upload(&2, :photo, &1.ref))
    |> assign(saved_at: nil, photo_error: nil, refused_words: %{}, waiting_words: MapSet.new())
    |> assign(:popover, nil)
  end

  defp present_section(socket, section) do
    socket
    |> assign(:shown, signature(section))
    |> assign(:form, section_form(section, socket.assigns.actor))
    |> assign(:picked, picked(section))
    |> assign(:photo_params, nil)
  end

  defp signature(section), do: {section.id, section.anchor, section.surface, section.content}

  defp section_form(section, actor) do
    section
    |> AshPhoenix.Form.for_update(:update,
      actor: actor,
      as: "section",
      id: "section-#{section.key}"
    )
    |> to_form()
  end

  # What the section's choices field holds, in the order it was picked.
  defp picked(section) do
    case choices_field(specs(section)) do
      nil -> []
      field -> Map.get(section.content.value, field) || []
    end
  end

  defp choices_field(specs),
    do: Enum.find_value(specs, fn {field, spec} -> spec[:as] == :choices && field end)

  defp specs(%{assigns: %{section: section}}), do: specs(section)

  # The component's fields, narrowed to what the site offers. A select
  # left with one is a choice the site has made, so the header doesn't
  # draw it.
  defp specs(section), do: EditorFields.narrowed(section.content.type)

  ## Events

  # The variant's buttons sit outside the section's params, as `variant`,
  # so a change of variant is told from a change of anything else.
  #
  # The header draws only some of the section's fields, so what it sends
  # goes over the form's own params: a part or list the form has been
  # handed params for, and so would take away if they left them out,
  # keeps them.
  @impl true
  def handle_event("change", params, socket) do
    specs = specs(socket)

    section_params =
      params |> Map.get("section", %{}) |> allowed(specs, socket.assigns, params["_target"])

    {section_params, picked} =
      keep_picked_order(section_params, socket.assigns.picked, choices_field(specs))

    section_params = deep_merge(base_params(socket), section_params)
    socket = assign(socket, :picked, picked)

    case new_variant(params["variant"], specs, socket.assigns.form) do
      nil ->
        save(socket, &AshPhoenix.Form.validate(&1, section_params))

      variant ->
        section_params = put_content(section_params, "variant", Atom.to_string(variant))

        save(socket, fn form ->
          form |> AshPhoenix.Form.validate(section_params) |> fill_shown_parts(specs, variant)
        end)
    end
  end

  # Words typed in place (`Billboard.Sections.Words`). Only a words field
  # the specs describe saves, in a part or list item the section has, and
  # only while the editor shows it and the part or list holding it
  # (`EditorFields.hidden_at?/3`), so words a binding replaces, or words for
  # a part the section's layout leaves out, can't be sent; any other path is
  # ignored. A refused change leaves the form as it was, so the next field's
  # words save on their own, and tells the hook why, with the words exactly
  # as they came, which is how the hook knows they're still what the field
  # holds; the hook keeps them.
  def handle_event("edit_words", %{"path" => path, "text" => text}, socket)
      when is_binary(path) and is_binary(text) do
    with {:ok, at, _spec} <- EditorFields.words(specs(socket), path),
         true <- held?(socket.assigns.form, at),
         false <- words_hidden?(socket, at) do
      prior = socket.assigns.form
      words = String.slice(text, 0, 5_000)
      params = put_words(prior.source, base_params(socket), at, words)
      socket = update(socket, :waiting_words, &MapSet.delete(&1, path))
      {:noreply, socket} = save(socket, &AshPhoenix.Form.validate(&1, params))

      {:noreply, settle_words(socket, prior, at, path, text)}
    else
      _elsewhere -> {:noreply, socket}
    end
  end

  def handle_event("edit_words", _params, socket), do: {:noreply, socket}

  # A list takes no more than its most. The new item takes the focus, in
  # its first words, selected to be typed over, as a new section does.
  def handle_event("add_item", %{"path" => path}, socket) when is_binary(path) do
    {:noreply, added} = add_item(socket, path)
    {:noreply, focus_added(added, length(items_at(socket, path)), path)}
  end

  # A click can arrive after its item has gone, as when two clicks race;
  # it then changes nothing.
  def handle_event("remove_item", %{"path" => path, "index" => index}, socket)
      when is_binary(path) and (is_binary(index) or is_integer(index)) do
    with {index, ""} <- Integer.parse(to_string(index)) do
      change_at(socket, path, :list, fn field_path, _spec ->
        fn form ->
          items = EditorFields.nested(form.source, [:content | field_path]) || []

          if index in 0..(length(items) - 1)//1,
            do: AshPhoenix.Form.remove_form(form, [:content | field_path] ++ [index]),
            else: form
        end
      end)
    else
      _not_an_index -> {:noreply, socket}
    end
  end

  # A moved item's tools are drawn again where it went, so the focus goes
  # with it, to the button that moved it, or the other one at an end.
  def handle_event("move_item", %{"path" => path, "index" => index, "dir" => dir}, socket)
      when is_binary(path) and (is_binary(index) or is_integer(index)) and dir in ~w(up down) do
    with {index, ""} <- Integer.parse(to_string(index)) do
      by = if dir == "up", do: -1, else: 1
      other = if dir == "up", do: "down", else: "up"
      at = "section-item-#{path}-#{index + by}"

      {:noreply, socket} =
        change_at(socket, path, :list, fn field_path, _spec ->
          &move_item(&1, field_path, index, by)
        end)

      {:noreply, focus(socket, ["#{at}-#{dir}", "#{at}-#{other}", "section-controls"])}
    else
      _not_an_index -> {:noreply, socket}
    end
  end

  # A part is added only where there's none, and taken only where there's
  # one the section can do without: one whose spec says `optional`. A
  # forged drop of any other part changes nothing.
  def handle_event("add_part", %{"path" => path}, socket) when is_binary(path) do
    change_at(socket, path, :part, fn field_path, spec ->
      if not part?(socket.assigns.form, field_path) do
        &AshPhoenix.Form.add_form(&1, [:content | field_path], params: Parts.blank(spec[:part]))
      end
    end)
  end

  def handle_event("drop_part", %{"path" => path}, socket) when is_binary(path) do
    change_at(socket, path, :part, fn field_path, spec ->
      if Keyword.get(spec, :optional, false) and part?(socket.assigns.form, field_path) do
        &AshPhoenix.Form.remove_form(&1, [:content | field_path])
      end
    end)
  end

  # A list's or a part's change sent without a path, or with an index or
  # direction it can't use, changes nothing.
  def handle_event(event, _params, socket)
      when event in ~w(add_item remove_item move_item add_part drop_part),
      do: {:noreply, socket}

  # A button, an action or a point's link, opens its popover under the
  # header, if the section has one there.
  def handle_event("edit_action", %{"path" => path}, socket) when is_binary(path),
    do: {:noreply, open_button(socket, path)}

  # The popover's fields, a detail's scope, or a card's ground: the fields
  # of the part or list item at `path` that its specs offer, sent under the
  # section's names for them (`section[content][actions][1][label]`). Only
  # they change, and only those the editor shows now
  # (`EditorFields.hidden_at?/3`): a part the layout leaves out, or words a
  # binding replaces, take nothing.
  def handle_event("edit_part", %{"path" => path} = params, socket) when is_binary(path) do
    with {:ok, at, part} <- part_at(socket, path),
         %{} = sent <- dig(params, ["section", "content" | String.split(path, ".")]),
         sent = surface_only_if_target(sent, path, params["_target"]),
         fields when fields != %{} <- part_params(socket, sent, at, part) do
      form = socket.assigns.form.source
      params = update_content(form, base_params(socket), at, &Map.merge(&1, fields))
      save(socket, &AshPhoenix.Form.validate(&1, params))
    else
      _nothing_to_change -> {:noreply, socket}
    end
  end

  # Enter in the popover's words: they save, and the popover closes.
  def handle_event("finish_part", %{"path" => path} = params, socket) when is_binary(path) do
    {:noreply, socket} = handle_event("edit_part", params, socket)
    handle_event("close_popover", %{}, socket)
  end

  # Takes a button away: an item from its list, or a part its section can
  # do without. Its popover goes with it.
  def handle_event("remove_button", %{"path" => path}, socket) when is_binary(path) do
    {list, [last]} = path |> String.split(".") |> Enum.split(-1)

    case {part_at(socket, path), Integer.parse(last)} do
      {{:ok, _at, part}, {index, ""}} when part in [:action, :link] ->
        list = Enum.join(list, ".")

        {:noreply, socket} =
          handle_event("remove_item", %{"path" => list, "index" => index}, socket)

        {:noreply, close_popover(socket, ["section-add-button-#{Words.dashed(list)}"])}

      {{:ok, _at, part}, _not_an_index} when part in [:action, :link] ->
        {:noreply, socket} = handle_event("drop_part", %{"path" => path}, socket)
        {:noreply, close_popover(socket, ["section-add-button-#{Words.dashed(path)}"])}

      _not_a_button ->
        {:noreply, socket}
    end
  end

  # Adds a button where it's drawn, at the end of a list of them, short of
  # the list's most, or as a part the section can do without, and opens
  # its popover. Nothing else is added this way.
  def handle_event("add_button", %{"path" => path}, socket) when is_binary(path) do
    with {:ok, at, spec} <- EditorFields.resolve(specs(socket), String.split(path, ".")),
         true <- spec[:part] in [:action, :link] do
      count = length(List.wrap(EditorFields.nested(socket.assigns.form.source, [:content | at])))

      if spec[:as] == :part do
        {:noreply, socket} = handle_event("add_part", %{"path" => path}, socket)
        {:noreply, open_button(socket, path)}
      else
        {:noreply, socket} = add_item(socket, path)
        {:noreply, open_button(socket, "#{path}.#{count}")}
      end
    else
      _not_a_button -> {:noreply, socket}
    end
  end

  def handle_event("close_popover", _params, socket) do
    back =
      case socket.assigns.popover do
        {:button, path} -> ["section-at-#{Words.dashed(path)}"]
        :photo -> ["section-photo-describe"]
        nil -> []
      end

    {:noreply, close_popover(socket, back)}
  end

  def handle_event("describe_photo", _params, socket) do
    if photo?(socket),
      do: {:noreply, socket |> assign(:popover, :photo) |> focus(["section-photo"])},
      else: {:noreply, socket}
  end

  # The popover's words count as they're typed, without their Markdown.
  def handle_event("count", %{"text" => text, "limit" => limit} = params, socket)
      when is_binary(text) and is_integer(limit) and limit > 0 do
    max =
      case params["max"] do
        max when is_integer(max) and max > 0 -> max
        _none -> nil
      end

    {:reply, EditorFields.count(String.slice(text, 0, 5_000), limit, max), socket}
  end

  def handle_event("count", _params, socket), do: {:noreply, socket}

  # The photograph's events, and an upload's arrival, change it only while
  # the section shows one (`photo?/1`), as Describe opens only then: a
  # layout without one keeps the photograph it holds, untouched.
  def handle_event("photo_change", params, socket) do
    photo = Map.get(params, "photo", %{})
    socket = assign(socket, photo_params: photo, photo_error: nil)

    # A photograph on its way waits for the form to be sent, words and all.
    if socket.assigns.uploads.photo.entries == [] and photo?(socket) do
      save(socket, &AshPhoenix.Form.validate(&1, photo_params(socket, photo, :keep)))
    else
      {:noreply, socket}
    end
  end

  # Enter in Describe's words: they save, and Describe closes.
  def handle_event("photo_save", params, socket) do
    photo = Map.get(params, "photo", %{})
    socket = socket |> assign(photo_params: photo, photo_error: nil) |> close_popover([])
    shown? = photo?(socket)

    case uploaded_entries(socket, :photo) do
      _any when not shown? ->
        {:noreply, socket}

      {[], []} ->
        save(socket, &AshPhoenix.Form.validate(&1, photo_params(socket, photo, :keep)))

      {_done, [_ | _]} ->
        {:noreply, assign(socket, :photo_error, "The photograph is still on its way. Try again.")}

      {_done, []} ->
        save_upload(socket, photo)
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photo, ref)}
  end

  # Takes the photograph away from the section, keeping what it shows for
  # the placeholder. The file stays: the live page may still show it.
  def handle_event("remove_photo", _params, socket) do
    if photo?(socket) do
      photo = %{"label" => photo_value(socket.assigns.form, :label), "alt" => ""}
      save(socket, &AshPhoenix.Form.validate(&1, photo_params(socket, photo, "")))
    else
      {:noreply, socket}
    end
  end

  # A photograph saves as soon as it has arrived, with the words Describe
  # last sent. One still arriving once the section shows none is called
  # off, so it isn't left waiting for a layout that shows it again.
  defp photo_progress(:photo, entry, socket) do
    cond do
      not photo?(socket) -> {:noreply, cancel_upload(socket, :photo, entry.ref)}
      entry.done? -> save_upload(socket, socket.assigns.photo_params || %{})
      true -> {:noreply, socket}
    end
  end

  # Checks the words before taking the photograph in. Once taken, it leaves
  # the upload, so a save that then failed would lose it. A photograph
  # needs words to read aloud for it: until Describe gives some, it has
  # what the placeholder said it shows.
  defp save_upload(socket, photo) do
    form = socket.assigns.form
    label = Map.get_lazy(photo, "label", fn -> photo_value(form, :label) end)
    alt = Map.get_lazy(photo, "alt", fn -> photo_value(form, :alt) end)
    described? = Parts.present?(alt)
    photo = if described?, do: photo, else: Map.put(photo, "alt", label || "")

    checked =
      AshPhoenix.Form.validate(
        socket.assigns.form,
        photo_params(socket, photo, "/uploads/pending")
      )

    if checked.source.valid? do
      stored =
        consume_uploaded_entries(socket, :photo, fn %{path: path}, _entry ->
          {:ok, Uploads.store_image(path)}
        end)

      case stored do
        [{:ok, path}] ->
          {:noreply, socket} =
            save(socket, &AshPhoenix.Form.validate(&1, photo_params(socket, photo, path)))

          saved? = photo_value(socket.assigns.form, :path) == path

          {:noreply, if(saved? and not described?, do: ask_for_description(socket), else: socket)}

        _not_an_image ->
          {:noreply,
           assign(socket, :photo_error, "That file is not a JPEG, PNG, or WebP photograph.")}
      end
    else
      {:noreply, assign(socket, :form, checked)}
    end
  end

  # The content params that set the photograph, from the photo form's words
  # and `path` (`:keep` for the one it has). Words the form leaves out keep
  # what they were.
  defp photo_params(socket, photo, path) do
    form = socket.assigns.form
    path = if path == :keep, do: photo_value(form, :path) || "", else: path

    put_content(base_params(socket), "photo", %{
      "label" => Map.get_lazy(photo, "label", fn -> photo_value(form, :label) || "" end),
      "alt" => Map.get_lazy(photo, "alt", fn -> photo_value(form, :alt) || "" end),
      "path" => path
    })
  end

  # Runs the change `make.(field_path, spec)` builds, for the field `path`
  # names, if it is a field of `as` in a part or list item the section has
  # (`held?/2`). Any other path is ignored, and so is a change `make`
  # doesn't build (nil), as when there's nothing to add or take away.
  defp change_at(socket, path, as, make) do
    with {:ok, field_path, spec} <- EditorFields.resolve(specs(socket), String.split(path, ".")),
         ^as <- spec[:as],
         true <- held?(socket.assigns.form, field_path),
         change when is_function(change, 1) <- make.(field_path, spec) do
      params = base_params(socket)
      save(socket, fn form -> form |> AshPhoenix.Form.validate(params) |> change.() end)
    else
      _elsewhere -> {:noreply, socket}
    end
  end

  # Swaps a list's item with its neighbour `by` away, by sending the items'
  # params, which carry their ids, in the new order.
  defp move_item(form, [field], index, by) do
    items =
      form.source
      |> EditorFields.nested([:content, field])
      |> Enum.map(&AshPhoenix.Form.params/1)

    other = index + by

    if index in 0..(length(items) - 1)//1 and other in 0..(length(items) - 1)//1 do
      moved =
        items
        |> List.replace_at(index, Enum.at(items, other))
        |> List.replace_at(other, Enum.at(items, index))

      params =
        form.source |> AshPhoenix.Form.params() |> put_content(Atom.to_string(field), moved)

      AshPhoenix.Form.validate(form, params)
    else
      form
    end
  end

  # A part or photograph the new variant shows, and the section must then
  # have, arrives with words to write over: a band turned to a quote gets a
  # quote, and a text only section turned to a photograph gets one.
  defp fill_shown_parts(form, specs, variant) do
    Enum.reduce(specs, form, fn {field, spec}, form ->
      shows? =
        variant not in (spec |> Keyword.get(:hide_when, []) |> Keyword.get(:variant, [variant]))

      if spec[:as] in [:part, :photo] and shows? and not Keyword.get(spec, :optional, false) and
           is_nil(EditorFields.nested(form.source, [:content, field])) do
        AshPhoenix.Form.add_form(form, [:content, field],
          params: Parts.blank(Keyword.get(spec, :part, :photo))
        )
      else
        form
      end
    end)
  end

  # The variant `sent` names, when it is one of the component's and not the
  # one it has.
  defp new_variant(sent, specs, form) when is_binary(sent) do
    options = specs |> Keyword.get(:variant, []) |> Keyword.get(:options, [])
    current = form.source |> EditorFields.nested([:content]) |> AshPhoenix.Form.value(:variant)

    Enum.find(
      options,
      &(Atom.to_string(&1) == sent and &1 != current and Atom.to_string(&1) != current)
    )
  end

  defp new_variant(_sent, _specs, _form), do: nil

  # Only what the editor offers reaches the section: its anchor, its
  # surface where the header offers one (`chosen_surface/4`), and the
  # content's fields its specs name, part by part and item by item, with
  # AshPhoenix's own keys (`_touched` and the like) and each part's `id`.
  # The content stays its own component. Anything else, such as a hero's
  # `bind`, or a photograph sent around its own form, is dropped, and so
  # is a field the editor leaves out now (`EditorFields.hidden?/2`, read
  # on its holder's form), such as words a binding replaces, or a part
  # the layout leaves out: the header never draws them, so it never sends
  # them, and they keep what they hold.
  defp allowed(params, specs, %{section: section, parent: parent, form: form}, target) do
    content =
      params
      |> Map.get("content", %{})
      |> only(specs, EditorFields.content_form(form))
      |> Map.put("_union_type", Atom.to_string(section.content.type))

    params
    |> Map.take(["anchor" | Enum.filter(Map.keys(params), &own_key?/1)])
    |> Map.merge(chosen_surface(params, section, parent, target))
    |> Map.put("content", content)
  end

  # The surface sent, but only while the header offers the section a
  # choice of them, and only when Ground itself is what changed, which
  # LiveView names in `_target`. The header sends its checked surface
  # with every change, whatever control changed, and that can be other
  # than the one the section names: its kind's default, for a section
  # that names none or one the site has stopped offering, or the one it
  # had before another admin chose again, if this browser hasn't drawn
  # the header since. Saving it with another setting's change would
  # record a choice nobody made, or undo someone else's.
  defp chosen_surface(%{"surface" => surface}, section, parent, ["section", "surface"])
       when is_binary(surface) do
    if ground(section, parent), do: %{"surface" => surface}, else: %{}
  end

  defp chosen_surface(_params, _section, _parent, _target), do: %{}

  # The surface the header shows as chosen: the form's, which is the saved
  # one or one held by a change the section turned down, resolved to its
  # kind's default where the site doesn't offer it.
  defp shown_surface(section, form),
    do: Surfaces.resolve(section.content.type, AshPhoenix.Form.value(form.source, :surface))

  # The Ground setting's spec: the surfaces the site offers the section's
  # kind, by their labels. There is none for a section that takes its
  # surface from elsewhere, such as a column, whatever the site offers,
  # nor where the site offers its kind one surface, as some sites always
  # do. A starter's column has no `parent_id`, since its Two
  # columns isn't saved yet, so a column is also known by `parent`, the
  # key the page editor finds it under.
  defp ground(%{content: %{type: type}, parent_id: parent_id}, parent) do
    with true <- is_nil(parent) and Surfaces.choosable?(type, parent_id),
         [_, _ | _] = names <- Surfaces.offered(Surfaces.kind(type)) do
      labels = Map.new(Surfaces.all(), &{&1.name, &1.label})
      [as: :select, label: "Ground", options: Enum.map(names, &{Map.fetch!(labels, &1), &1})]
    else
      _no_choice -> nil
    end
  end

  # `form` is the holder's form, as the editor draws it. A part or list
  # item the section hasn't got draws none of its fields, so, as
  # `EditorFields.hidden_at?/3` reads it, none is shown to change, and
  # its params go (`keep_shown/5`): a change never adds one.
  defp only(params, specs, form) when is_map(params) do
    fields = Map.new(specs, fn {field, spec} -> {Atom.to_string(field), {field, spec}} end)

    Enum.reduce(params, %{}, fn {key, value}, kept ->
      case keep(key, value, fields[key], form) do
        :drop -> kept
        value -> Map.put(kept, key, value)
      end
    end)
  end

  defp only(_params, _specs, _form), do: %{}

  defp keep(key, value, _field, _form) when key == "id" or binary_part(key, 0, 1) == "_",
    do: value

  defp keep(_key, _value, nil, _form), do: :drop

  defp keep(key, value, {field, spec}, form) do
    if EditorFields.hidden?(form, spec),
      do: :drop,
      else: keep_shown(key, value, field, spec, form)
  end

  # A card's surface is dropped here, as a photo is: it saves only through
  # its own Ground, by `edit_part`, which checks that Ground is what
  # changed. Kept from the header's change, it would save a surface sent
  # with another setting's change, which nobody chose.
  defp keep_shown(_key, value, field, spec, form) do
    part_specs = spec[:part] && Parts.editor_fields(spec[:part])

    case Keyword.get(spec, :as, :text) do
      as when as in [:photo, :note, :binding_note, :variants, :surface] ->
        :drop

      :part ->
        case EditorFields.sub_form(form, [field]) do
          nil -> :drop
          part_form -> only(value, part_specs, part_form)
        end

      :list when is_map(value) ->
        for {i, item} <- value,
            item_form = item_form(form, field, i),
            into: %{},
            do: {i, only(item, part_specs, item_form)}

      :list ->
        :drop

      _field ->
        value
    end
  end

  defp item_form(form, field, i) do
    case Integer.parse(i) do
      {index, ""} when index >= 0 -> EditorFields.sub_form(form, [field, index])
      _not_an_index -> nil
    end
  end

  defp own_key?(key), do: String.starts_with?(key, "_")

  # Ticked choices go after those already picked, so the order they
  # show in is the order they were ticked in.
  defp keep_picked_order(params, picked, nil), do: {params, picked}

  defp keep_picked_order(params, picked, field) do
    name = Atom.to_string(field)

    case params do
      %{"content" => %{^name => values}} when is_list(values) ->
        ticked = Enum.reject(values, &(&1 == ""))
        ordered = Enum.filter(picked, &(&1 in ticked)) ++ (ticked -- picked)
        {put_in(params, ["content", name], ["" | ordered]), ordered}

      _other ->
        {params, picked}
    end
  end

  # The params of the open section's form, which hold any change it turned
  # down. A change made to the draft's section starts from them.
  defp base_params(socket),
    do: socket.assigns.form |> AshPhoenix.Form.params() |> Map.delete("id")

  defp put_content(params, key, value),
    do: Map.update(params, "content", %{key => value}, &Map.put(&1, key, value))

  defp deep_merge(base, params) do
    Map.merge(base, params, fn
      _key, %{} = base, %{} = params when not is_struct(base) and not is_struct(params) ->
        deep_merge(base, params)

      _key, _base, params ->
        params
    end)
  end

  # Whether the form holds the part or list item the words at `at` belong
  # in. `EditorFields.words/2` resolves from the specs alone, so a path to
  # a point the section hasn't got, or to a part it leaves out, gets there.
  defp held?(form, at), do: part?(form, Enum.drop(at, -1))

  # Whether the words field at `at` is left out now, or the part or list
  # holding it is, each read on its holder's form, as the editor draws it.
  defp words_hidden?(socket, at) do
    EditorFields.hidden_at?(EditorFields.content_form(socket.assigns.form), specs(socket), at)
  end

  # The params with `text` at `at`, under the content (`[:points, 1, :body]`).
  defp put_words(form, params, at, text) do
    field = at |> List.last() |> Atom.to_string()
    update_content(form, params, Enum.drop(at, -1), &Map.put(&1, field, text))
  end

  # The params with the part or list item at `at` under the content
  # (`[:points, 1]`, `[:head, :action]`, `[]` for the content itself)
  # changed by `fun`. A list's params are the whole list, item by item
  # from the form, each with its id: AshPhoenix takes a list's params as
  # all of its items, so sending only the one changed would drop the rest.
  defp update_content(form, params, at, fun) do
    content = Map.get(params, "content", %{})
    Map.put(params, "content", update_at(EditorFields.nested(form, [:content]), content, at, fun))
  end

  defp update_at(_form, params, [], fun), do: fun.(params)

  defp update_at(form, params, [field, index | rest], fun) when is_integer(index) do
    item_forms = EditorFields.nested(form, [field])
    items = Enum.map(item_forms, &AshPhoenix.Form.params/1)
    item = update_at(Enum.at(item_forms, index), Enum.at(items, index), rest, fun)
    Map.put(params, Atom.to_string(field), List.replace_at(items, index, item))
  end

  defp update_at(form, params, [field | rest], fun) do
    part_form = EditorFields.nested(form, [field])

    part =
      Map.get_lazy(params, Atom.to_string(field), fn -> AshPhoenix.Form.params(part_form) end)

    Map.put(params, Atom.to_string(field), update_at(part_form, part, rest, fun))
  end

  # The part or list item `path` names (`"actions.1"`, `"head.action"`,
  # `"points.0.link"`, `"items.2"`), as its form path under the content,
  # with the part it is, if the form holds it. Only the specs' parts and
  # lists resolve, as `EditorFields.resolve/2` has them.
  defp part_at(socket, path), do: locate(socket.assigns.form, specs(socket), path)

  defp locate(form, specs, path) do
    segments = String.split(path, ".")

    {at, as} =
      case Integer.parse(List.last(segments)) do
        {index, ""} when index >= 0 -> {Enum.drop(segments, -1), {:list, index}}
        _not_an_index -> {segments, :part}
      end

    case EditorFields.resolve(specs, at) do
      {:ok, at, spec} -> held_part(form, at, spec, as)
      :error -> :error
    end
  end

  # The list's item, or the part, if the form holds it.
  defp held_part(form, at, spec, as) do
    at =
      case {spec[:as], as} do
        {:list, {:list, index}} -> at ++ [index]
        {:part, :part} -> at
        _other -> nil
      end

    if at && part?(form, at), do: {:ok, at, spec[:part]}, else: :error
  end

  # The kinds of a part's fields `edit_part` saves.
  @part_kinds [:text, :markdown, :select, :toggle, :number, :choice, :surface]

  # What `sent` has for the part's fields that its specs offer as words or
  # choices; nothing else, not even its id. A choice is every one (""),
  # one of the site's choices in its set (`from`), or the one it has, even
  # if that one has gone. A card's surface is its section's ("") or one
  # the site offers cards. Anything else is dropped.
  defp part_params(socket, sent, at, part) do
    specs = Parts.editor_fields(part)
    form = EditorFields.nested(socket.assigns.form.source, [:content | at])

    offered =
      for {field, spec} <- specs,
          Keyword.get(spec, :as, :text) in @part_kinds,
          into: %{},
          do: {Atom.to_string(field), {Keyword.get(spec, :as, :text), spec[:from]}}

    content_form = EditorFields.content_form(socket.assigns.form)
    section_specs = specs(socket)

    for {field, value} <- Map.take(sent, Map.keys(offered)),
        is_binary(value),
        not EditorFields.hidden_at?(
          content_form,
          section_specs,
          at ++ [String.to_existing_atom(field)]
        ),
        part_value?(offered[field], value, socket, form, field),
        into: %{},
        do: {field, value}
  end

  defp part_value?({:choice, from}, value, socket, form, field) do
    value in ["", to_string(AshPhoenix.Form.value(form, String.to_existing_atom(field)))] or
      List.keymember?(socket.assigns.choices[from].options, value, 1)
  end

  defp part_value?({:surface, _from}, value, _socket, _form, _field),
    do: value == "" or value in Surfaces.offered(:card)

  defp part_value?(_as, _value, _socket, _form, _field), do: true

  # A card's surface, but only when its Ground is what changed, which
  # LiveView names in `_target`. Ground shows a surface the site has
  # stopped offering as the section's, so sent with any other change it
  # would record a choice nobody made; its form holds nothing else today,
  # and this keeps it so if another control joins it.
  defp surface_only_if_target(sent, path, target) do
    if target == ["section", "content" | String.split(path, ".")] ++ ["surface"],
      do: sent,
      else: Map.delete(sent, "surface")
  end

  defp dig(value, []), do: value
  defp dig(%{} = map, [key | rest]), do: dig(Map.get(map, key), rest)
  defp dig(_value, _keys), do: nil

  # Opens Describe with the photograph's words ready to be typed over: a
  # new one is described by its placeholder's words until they are.
  defp ask_for_description(socket) do
    socket
    |> assign(:popover, :photo)
    |> focus(["photo-#{socket.assigns.section.key}_alt", "section-photo"], select: true)
  end

  # Opens the popover of the button at `path`, if the section has one
  # there, and takes the focus into it.
  defp open_button(socket, path) do
    case part_at(socket, path) do
      {:ok, _at, part} when part in [:action, :link] ->
        socket |> assign(:popover, {:button, path}) |> focus(["section-button"])

      _not_a_button ->
        socket
    end
  end

  # Closes the open popover, handing the focus to the first of `ids` on
  # the page, or the header.
  defp close_popover(%{assigns: %{popover: nil}} = socket, _ids), do: socket

  defp close_popover(socket, ids),
    do: socket |> assign(:popover, nil) |> focus(ids ++ ["section-controls"])

  defp add_item(socket, path) do
    change_at(socket, path, :list, fn field_path, spec ->
      items = EditorFields.nested(socket.assigns.form.source, [:content | field_path]) || []

      if length(items) < Keyword.get(spec, :max, 12),
        do:
          &AshPhoenix.Form.add_form(&1, [:content | field_path], params: Parts.blank(spec[:part]))
    end)
  end

  # The items of the list at `path`, as the form holds them.
  defp items_at(socket, path) do
    case EditorFields.resolve(specs(socket), String.split(path, ".")) do
      {:ok, field_path, _spec} ->
        EditorFields.nested(socket.assigns.form.source, [:content | field_path]) || []

      _elsewhere ->
        []
    end
  end

  # After an item was added at `path`, where there were `before`, the
  # focus goes to its first words, if it has any, or the header. The page
  # editor draws the item's words once it has read the saved section
  # (`{:section_saved, key}`), after this editor's own reply, so it's the
  # one to move the focus, after that (`{:editor_focus, payload}`).
  defp focus_added(socket, before, path) do
    if length(items_at(socket, path)) > before do
      send(
        self(),
        {:editor_focus,
         %{
           ids: ["section-controls"],
           words: socket.assigns.section.key,
           at: "#{Words.dashed(path)}-#{before}",
           scroll: true,
           select: true
         }}
      )
    end

    socket
  end

  # Moves the focus to the first of the elements `ids` names that's on the
  # page once it's drawn, as the page editor does (its bar's `.EditorBar`).
  defp focus(socket, ids, opts \\ []) do
    push_event(socket, "editor:focus", %{
      ids: ids,
      scroll: false,
      select: Keyword.get(opts, :select, false)
    })
  end

  defp photo?(socket),
    do: photo_shown?(specs(socket), EditorFields.content_form(socket.assigns.form))

  # Whether the section's layout shows a photograph: one of `specs` is a
  # photo the content's form doesn't hide. The header draws the
  # photograph's controls, and its events change it, only then.
  defp photo_shown?(specs, content_form) do
    Enum.any?(specs, fn {_field, spec} ->
      Keyword.get(spec, :as, :text) == :photo and not EditorFields.hidden?(content_form, spec)
    end)
  end

  # After words typed in place were tried. Turned down, by the open
  # section or the draft's, the form goes back to `prior`, and the hook is
  # told why, in plain words: the field's own problem, or else the first
  # there is. When a control's change the section turned down was there
  # before them, the words wait on it, and say which control it is. `text`
  # is as it came, so the hook can tell it's still what the field holds.
  #
  # A save turned down with no error on the form (the section changed
  # under the admin, or went) tells the hook nothing: it shows the stored
  # words once the field is left, and the page editor's flash says why.
  defp settle_words(socket, prior, at, path, text) do
    case form_errors(socket.assigns.form) do
      [] ->
        update(socket, :refused_words, &Map.delete(&1, path))

      [{_at, first} | _] = errors ->
        {message, waiting?} =
          case {List.keyfind(errors, [:content | at], 0), form_errors(prior)} do
            {{_at, own}, _before} -> {plain(own), false}
            {nil, []} -> {plain(first), false}
            {nil, [{blocker, why} | _]} -> {waiting(blocker, why, specs(socket)), true}
          end

        socket
        |> assign(:form, prior)
        |> update(:refused_words, &Map.put(&1, path, message))
        |> update(:waiting_words, &if(waiting?, do: MapSet.put(&1, path), else: &1))
        |> push_event("words:refused", %{
          section: socket.assigns.section.key,
          path: path,
          text: text,
          message: message
        })
    end
  end

  # Why words wait: the control to fix first, by its name, or else what's
  # wrong with it. It isn't "Not saved yet: first fix…", which the issue
  # strip would draw after the words' name and a colon of its own.
  defp waiting(blocker, why, specs) do
    case problem_label(blocker, specs) do
      nil -> "Not saved yet. " <> plain(why)
      label -> "Not saved yet. First fix the #{label}."
    end
  end

  # The form's errors, each with the form path to its field.
  defp form_errors(form) do
    for {form_path, errors} <- AshPhoenix.Form.errors(form, for_path: :all),
        {field, message} <- errors,
        do: {form_path ++ [field], message}
  end

  # Whether the form holds the part or list item at `field_path` under the
  # content. A negative index would count from the list's end, so it never is.
  defp part?(form, field_path) do
    Enum.all?(field_path, &(not is_integer(&1) or &1 >= 0)) and
      not is_nil(EditorFields.nested(form.source, [:content | field_path]))
  end

  defp photo_value(form, field) do
    case EditorFields.nested(form.source, [:content, :photo]) do
      nil -> nil
      photo -> AshPhoenix.Form.value(photo, field)
    end
  end

  ## Saving

  defp save(socket, change) do
    checked = change.(socket.assigns.form)

    if checked.source.valid?,
      do: save_to_draft(socket, change, checked),
      else: {:noreply, assign(socket, :form, checked)}
  end

  defp save_to_draft(socket, change, checked) do
    %{page: page, section: %{key: key}, actor: actor} = socket.assigns

    result =
      Pages.change_draft(
        page.pattern,
        fn _draft, sections ->
          case Map.fetch(sections, key) do
            {:ok, section} ->
              section |> section_form(actor) |> change.() |> AshPhoenix.Form.submit(params: nil)

            :error ->
              {:error, :gone}
          end
        end,
        actor: actor
      )

    Pages.drain_page_changes(page.pattern)

    case result do
      {:ok, saved} ->
        send(self(), {:section_saved, key})

        {:noreply,
         socket
         |> assign(saved_at: DateTime.utc_now(), photo_error: nil)
         |> present_section(saved)
         |> retry_words()}

      {:error, %Phoenix.HTML.Form{} = form} ->
        refused(socket, checked, form.source)

      {:error, %AshPhoenix.Form{} = form} ->
        refused(socket, checked, form)

      # Turned down with nothing to show on the form, such as the section
      # having gone: the page editor's flash says why.
      {:error, error} ->
        send(self(), {:section_refused, message(error)})
        {:noreply, socket}
    end
  end

  # Words that waited on a control's change the section turned down go
  # again once a change saves, which none can while that change is held.
  # The hook sends them if they're still what their field holds.
  defp retry_words(%{assigns: %{waiting_words: waiting}} = socket) do
    if Enum.empty?(waiting) do
      socket
    else
      paths = Enum.sort(waiting)

      socket
      |> update(:refused_words, &Map.drop(&1, paths))
      |> assign(:waiting_words, MapSet.new())
      |> push_event("words:retry", %{section: socket.assigns.section.key, paths: paths})
    end
  end

  # The draft's section turned down a change the open section took, such
  # as a link name another section of the draft has. Its errors go on the
  # open section's form: the draft's section may be gone with the
  # transaction that turned the change down, as a first change's is. With
  # nothing to say, the section changed under the admin, such as a list
  # item another admin removed: the editor takes it afresh.
  defp refused(socket, checked, draft_form) do
    errors =
      for {path, errors} <- AshPhoenix.Form.errors(draft_form, for_path: :all),
          {field, message} <- errors,
          do: {path, field, message}

    if errors == [] do
      send(self(), {:section_refused, message(:stale)})
      {:noreply, socket |> present_section(socket.assigns.section) |> retry_words()}
    else
      form =
        Enum.reduce(errors, checked, fn {path, field, message}, form ->
          error = Ash.Error.Changes.InvalidAttribute.exception(field: field, message: message)
          AshPhoenix.Form.add_error(form, error, if(path == [], do: [], else: [path: path]))
        end)

      {:noreply, assign(socket, :form, form)}
    end
  end

  ## Rendering

  @setting_kinds [:select, :toggle, :number, :choice, :choices, :shared]

  # The controls header, then the strip saying what's wrong, each known by
  # an id the field it's about points at (`aria-errormessage`): a words
  # field's id with `-refused`, or `section-error-` and the field. The
  # photograph's upload has a form of its own, as an upload must live in
  # this component; the tools over the photo click its file input, and
  # open Describe, which is in it. A button's popover hangs under them
  # all, as Describe does, so both stay in sight while the page scrolls.
  #
  # Every button sits in the header's form, so each one says it's only a
  # button: a button in a form sends it otherwise.
  @impl true
  def render(assigns) do
    section = assigns.section
    specs = specs(section)

    content_form = EditorFields.content_form(assigns.form)

    shown =
      specs
      |> EditorFields.binding_notes(content_form)
      |> Enum.reject(fn {_field, spec} -> EditorFields.hidden?(content_form, spec) end)

    as = fn spec -> Keyword.get(spec, :as, :text) end

    count = fn field ->
      length(EditorFields.nested(assigns.form.source, [:content, field]) || [])
    end

    present? = &part?(assigns.form, [&1])
    photo? = photo_shown?(specs, content_form)

    # A part the section can do without, other than a button, which is
    # changed where it's drawn.
    optional =
      for {field, spec} <- shown,
          as.(spec) == :part,
          spec[:optional],
          spec[:part] != :action,
          do: {field, spec}

    shared? = section.content.type == :shared
    ground = ground(section, assigns.parent)

    assigns =
      assign(assigns,
        key: section.key,
        name: Catalogue.label(section.content.type),
        hero?: section.content.type == :hero,
        fixed?: is_list(assigns.page.fixed),
        columns?: section.content.type == :columns,
        shared?: shared?,
        library_key: library_key(section, assigns.page),
        uses: uses(section, assigns.page, assigns.uses),
        photo?: photo?,
        # One layout, or none, is a choice the site has made, as a select
        # with one option is.
        variants:
          Enum.find_value(shown, fn {_field, spec} ->
            as.(spec) == :variants && match?([_, _ | _], spec[:options]) && spec[:options]
          end),
        variant: to_string(content_form[:variant].value),
        ground: ground,
        surface: ground && shown_surface(section, assigns.form),
        settings:
          for(
            {field, spec} <- shown,
            as.(spec) in @setting_kinds,
            as.(spec) != :select or match?([_, _ | _], spec[:options]),
            do:
              {field,
               if(as.(spec) == :shared, do: [label: "Swap for another"] ++ spec, else: spec)}
          ),
        notes: for({_field, spec} <- shown, as.(spec) == :note, do: spec),
        adds:
          for(
            {field, spec} <- shown,
            as.(spec) == :list,
            spec[:part] != :action,
            count.(field) < Keyword.get(spec, :max, 12),
            do: {field, spec, count.(field) + 1 >= Keyword.get(spec, :max, 12)}
          ) ++
            for({field, spec} <- optional, not present?.(field), do: {field, spec, true}),
        drops: for({field, spec} <- optional, present?.(field), do: {field, spec}),
        more_words:
          for(
            {field, spec} <- shown,
            as.(spec) == :text,
            EditorFields.more?(spec),
            do: {field, spec}
          ),
        # A shared section is drawn with its library section's link name.
        anchor?: section.content.type not in [:hero, :shared],
        specs: specs,
        button: button(assigns.popover, assigns.form, content_form, specs),
        photo_form: photo? && photo_form(assigns.form, assigns.photo_params, section.key),
        has_photo?: photo? && Parts.present?(photo_value(assigns.form, :path)),
        # A photograph described by its placeholder's words, as a new one
        # is until Describe says more.
        label_alt?:
          photo? && Parts.present?(photo_value(assigns.form, :path)) &&
            photo_value(assigns.form, :alt) == photo_value(assigns.form, :label),
        ctx: %{
          key: section.key,
          target: assigns.myself,
          page: assigns.page,
          choices: assigns.choices,
          library: swap_choices(section, assigns.page, assigns.library, assigns.uses)
        },
        problems: problems(assigns.form, specs)
      )

    ~H"""
    <div
      id="section-editor"
      data-section={@key}
      data-editor-ui
      class="sticky top-[var(--bb-edit-bar-height,0px)] z-30"
    >
      <.form
        for={@form}
        id="section-settings"
        phx-change="change"
        phx-submit="change"
        phx-target={@myself}
      >
        <div
          id="section-controls"
          role="group"
          aria-label={"#{@name}: its settings"}
          tabindex="-1"
          class="flex flex-wrap items-center gap-x-3 gap-y-2 bg-bb-edit px-4 py-2 font-bb-edit text-[13px] leading-tight text-bb-edit-on-accent outline-none focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-bb-edit-on-accent md:px-6"
        >
          <.inputs_for :let={content} field={@form[:content]}>
            <button
              :if={@parent}
              id="section-open-columns"
              type="button"
              phx-click={JS.push("open_section", value: %{key: @parent})}
              aria-label="Open the Two columns around this section"
              class={EditorFields.setting_button_class()}
            >
              Two columns <span aria-hidden="true">›</span>
            </button>
            <p class="mr-1 font-semibold">{@name}</p>

            <button
              :if={@moves[:remove]}
              id="section-remove"
              type="button"
              phx-click="remove_section"
              phx-value-key={@key}
              data-confirm={
                if(@shared?,
                  do:
                    "Take this section off this page? It stays in the shared library, and on the other pages that show it.",
                  else: "Remove this section?"
                )
              }
              class={EditorFields.setting_button_class()}
            >
              {if @shared?, do: "Remove from this page", else: "Remove section"}
            </button>
            <p :if={@fixed?} id="section-fixed" class="text-xs opacity-85">
              This page's sections are fixed.
            </p>
            <p :if={@hero? && !@fixed?} class="text-xs opacity-85">
              Every page opens with its hero.
            </p>
            <p :if={@uses} id="section-shared-uses" class="max-w-prose text-xs opacity-90">
              {@uses}
            </p>

            <fieldset :if={@variants} id="section-layout" class="flex items-center gap-2">
              <legend class="sr-only">Layout</legend>
              <span class="opacity-80" aria-hidden="true">Layout</span>
              <span class="inline-flex flex-wrap rounded-[6px] bg-bb-edit-ground/12 p-0.5">
                <label
                  :for={variant <- @variants}
                  for={"section-variant-#{variant}"}
                  title={EditorFields.variant_label(variant, :short)}
                  class={EditorFields.segment_class()}
                >
                  <input
                    type="radio"
                    id={"section-variant-#{variant}"}
                    name="variant"
                    value={variant}
                    checked={@variant == to_string(variant)}
                    class="sr-only"
                  />
                  <EditorFields.variant_glyph variant={variant} />
                  <span class="max-sm:sr-only">{EditorFields.variant_label(variant, :short)}</span>
                </label>
              </span>
            </fieldset>

            <button
              :if={@columns? && !@fixed?}
              id="section-swap-columns"
              type="button"
              phx-click="swap_columns"
              phx-value-key={@key}
              class={EditorFields.setting_button_class()}
            >
              <span aria-hidden="true">⇄</span> Swap sides
            </button>

            <EditorFields.setting
              :if={@ground}
              form={@form}
              field={:surface}
              spec={@ground}
              chosen={@surface}
              ctx={@ctx}
              error_id={setting_error_id([:surface])}
            />

            <EditorFields.setting
              :for={{field, spec} <- @settings}
              form={content}
              field={field}
              spec={spec}
              ctx={@ctx}
              error_id={setting_error_id([:content, field])}
            />

            <p
              :for={{spec, i} <- Enum.with_index(@notes)}
              id={if(i == 0, do: "section-note", else: "section-note-#{i}")}
              class="max-w-prose text-xs opacity-90"
            >
              {spec[:text]}
              <.link
                :if={spec[:link]}
                navigate={elem(spec[:link], 1)}
                class="ml-1 font-semibold whitespace-nowrap underline underline-offset-2 transition-[text-decoration-color] duration-[var(--bb-edit-duration)] ease-bb-edit hover:decoration-transparent"
              >
                {elem(spec[:link], 0)} <span aria-hidden="true">›</span>
              </.link>
            </p>

            <.link
              :if={@shared? && @library_key}
              id="section-edit-in-library"
              patch={@editor_path.(nil, open: @library_key)}
              class={EditorFields.setting_button_class()}
            >
              Edit in library <span aria-hidden="true">›</span>
            </.link>

            <button
              :for={{field, spec, last?} <- @adds}
              id={"section-add-#{field}"}
              type="button"
              phx-click={add_click(spec, field, last?, @myself)}
              class={EditorFields.setting_button_class()}
            >
              <span aria-hidden="true">+</span> {EditorFields.add_words(spec)}
            </button>

            <details
              :if={@more_words != [] or @anchor? or @drops != []}
              id="section-more"
              class="relative open:max-sm:basis-full"
              phx-mounted={JS.ignore_attributes(["open"])}
              phx-click-away={JS.remove_attribute("open", to: "#section-more")}
            >
              <summary class={[
                EditorFields.setting_button_class(),
                "list-none [&::-webkit-details-marker]:hidden"
              ]}>
                <span>More<span aria-hidden="true">…</span></span>
              </summary>
              <div class="z-40 mt-2 grid w-80 max-w-[calc(100vw-2rem)] gap-5 bg-bb-edit-ground p-4 text-bb-edit-ink shadow-bb-edit-popover sm:absolute sm:top-full sm:right-0">
                <Components.input
                  :for={{field, spec} <- @more_words}
                  field={plain_errors(content[field])}
                  label={spec[:label]}
                  hint={spec[:hint]}
                  phx-debounce="blur"
                  aria-invalid={content[field].errors != [] && "true"}
                  aria-errormessage={
                    content[field].errors != [] && setting_error_id([:content, field])
                  }
                />
                <Components.input
                  :if={@anchor?}
                  field={plain_errors(@form[:anchor])}
                  label="Link name"
                  hint={anchor_hint()}
                  phx-debounce="blur"
                  aria-invalid={@form[:anchor].errors != [] && "true"}
                  aria-errormessage={@form[:anchor].errors != [] && setting_error_id([:anchor])}
                />
                <button
                  :for={{field, spec} <- @drops}
                  id={"section-drop-#{field}"}
                  type="button"
                  phx-click={
                    JS.push("drop_part", value: %{path: field}, target: @myself)
                    |> JS.focus(to: "#section-more > summary")
                  }
                  class="bb-edit-type-label min-h-11 cursor-pointer justify-self-start text-bb-edit-error underline underline-offset-4 transition-[text-decoration-color] duration-[var(--bb-edit-duration)] ease-bb-edit hover:decoration-transparent"
                >
                  Remove the {spec[:item_label]}
                </button>
              </div>
            </details>

            <div class="ml-auto flex items-center gap-2">
              <button
                :for={{dir, words} <- [up: "Up", down: "Down"]}
                :if={@moves[dir]}
                id={"section-move-#{dir}"}
                type="button"
                phx-click="move"
                phx-value-key={@key}
                phx-value-dir={dir}
                aria-label={"Move this section #{dir}"}
                class={EditorFields.setting_button_class()}
              >
                <span aria-hidden="true">{if dir == :up, do: "↑", else: "↓"}</span> {words}
              </button>
              <button
                id="section-done"
                type="button"
                phx-click="close_section"
                class={EditorFields.setting_button_class(:done)}
              >
                Done
              </button>
            </div>
          </.inputs_for>
        </div>
      </.form>

      <div
        :if={@issues != [] or @problems != [] or @refused_words != %{} or @label_alt?}
        id="section-issues"
        role={if(errors?(@issues, @problems, @refused_words), do: "alert", else: "status")}
        class="bg-bb-edit-ground"
      >
        <ul class={[
          "flex flex-wrap gap-x-5 gap-y-1 px-4 py-2 font-bb-edit text-[13px] font-medium md:px-6",
          if(errors?(@issues, @problems, @refused_words),
            do: "bg-bb-edit-error/8",
            else: "bg-bb-edit-line/40"
          )
        ]}>
          <li
            :for={{issue, i} <- Enum.with_index(@issues)}
            id={"section-issue-#{i}"}
            data-level={issue.level}
            class={if(issue.level == :error, do: "text-bb-edit-error", else: "text-bb-edit-soft")}
          >
            {sentence(issue.message)}
          </li>
          <li
            :if={@label_alt?}
            id="section-photo-described"
            data-level="warning"
            class="text-bb-edit-soft"
          >
            This photograph is described by its placeholder's words. Check they say what it shows.
          </li>
          <li
            :for={{at, label, messages} <- @problems}
            id={setting_error_id(at)}
            data-level="error"
            class="text-bb-edit-error"
          >
            {label && "#{label}: "}{Enum.join(messages, " ")}
          </li>
          <li
            :for={{path, message} <- Enum.sort(@refused_words)}
            id={"#{Words.id(@key, path)}-refused"}
            data-level="error"
            class="text-bb-edit-error"
          >
            {words_label(path, @specs)}{message}
          </li>
        </ul>
      </div>

      <.form
        :if={@photo?}
        for={@photo_form}
        id={"photo-form-#{@key}"}
        phx-change="photo_change"
        phx-submit="photo_save"
        phx-target={@myself}
      >
        <.live_file_input upload={@uploads.photo} class="sr-only" tabindex="-1" />
        <div
          :for={entry <- @uploads.photo.entries}
          id="section-photo-progress"
          role="status"
          class="flex items-center gap-4 bg-bb-edit-ground px-4 py-2 font-bb-edit text-[13px] text-bb-edit-ink md:px-6"
        >
          <p class="min-w-0 flex-1 truncate">Uploading {entry.client_name}</p>
          <progress value={entry.progress} max="100" class="h-1 w-24 accent-bb-edit">
            {entry.progress}%
          </progress>
          <button
            id="section-photo-cancel"
            type="button"
            phx-click="cancel_upload"
            phx-value-ref={entry.ref}
            phx-target={@myself}
            aria-label={"Stop uploading #{entry.client_name}"}
            class="min-h-8 cursor-pointer font-semibold text-bb-edit-soft underline underline-offset-4 transition-[text-decoration-color] duration-[var(--bb-edit-duration)] ease-bb-edit hover:decoration-transparent pointer-coarse:min-h-11"
          >
            Cancel
          </button>
        </div>
        <p
          :for={message <- photo_errors(@uploads.photo, @photo_error)}
          role="alert"
          class="bb-edit-type-small bg-bb-edit-paper px-4 py-2 text-bb-edit-error"
        >
          {message}
        </p>

        <div
          :if={@popover == :photo}
          id="section-photo"
          role="dialog"
          aria-labelledby="section-photo-title"
          tabindex="-1"
          class={popover_class()}
          phx-click-away={JS.push("close_popover", target: @myself)}
        >
          <h2 id="section-photo-title" class="bb-edit-type-label text-bb-edit-soft">
            Describe the photograph
          </h2>
          <Components.input
            field={@photo_form[:label]}
            label="What it shows"
            hint="Drawn on the placeholder until there's a photograph."
            phx-debounce="blur"
          />
          <Components.input
            :if={@has_photo?}
            field={@photo_form[:alt]}
            label="Description"
            hint="Read aloud to people who can't see the photograph."
            phx-debounce="blur"
          />
          <div class="flex justify-end">
            <Components.button
              id="section-photo-done"
              type="button"
              phx-click={JS.push("close_popover", target: @myself)}
            >
              Done
            </Components.button>
          </div>
        </div>
      </.form>

      <div
        :if={@button}
        id="section-button"
        role="dialog"
        aria-labelledby="section-button-title"
        tabindex="-1"
        class={popover_class()}
        phx-click-away={JS.push("close_popover", target: @myself)}
      >
        <h2 id="section-button-title" class="bb-edit-type-label text-bb-edit-soft">
          {@button.title}
        </h2>
        <.form
          for={%{}}
          id="section-button-form"
          phx-change="edit_part"
          phx-submit="finish_part"
          phx-target={@myself}
          class="grid gap-4"
        >
          <input type="hidden" name="path" value={@button.path} />
          <EditorFields.fields
            form={@button.form}
            specs={Parts.editor_fields(@button.part)}
            ctx={@ctx}
          />
        </.form>
        <div class="flex items-center justify-between gap-4">
          <button
            id="section-button-remove"
            type="button"
            phx-click={JS.push("remove_button", value: %{path: @button.path}, target: @myself)}
            class="bb-edit-type-label min-h-11 cursor-pointer text-bb-edit-error underline underline-offset-4 transition-[text-decoration-color] duration-[var(--bb-edit-duration)] ease-bb-edit hover:decoration-transparent"
          >
            Remove {@button.name}
          </button>
          <Components.button
            id="section-button-done"
            type="button"
            phx-click={JS.push("close_popover", target: @myself)}
          >
            Done
          </Components.button>
        </div>
      </div>
    </div>
    """
  end

  # The library section this section is: a Shared section's, on a page,
  # or the section itself, in the library.
  defp library_key(%{content: %{type: :shared, value: %{key: key}}}, _page), do: key
  defp library_key(section, %{kind: :library}), do: section.key
  defp library_key(_section, _page), do: nil

  # Which pages show a library section: on a page, the pages that share
  # this Shared section's, this one first; in the library, the pages that
  # place it, as visitors see them.
  defp uses(%{content: %{type: :shared, value: %{key: key}}}, page, uses) do
    case for(other <- Map.get(uses, key, []), other.pattern != page.pattern, do: other.label) do
      [] -> "Only on this page so far."
      others -> "Shared with #{length(others) + 1} pages: #{and_list(["this one" | others])}."
    end
  end

  defp uses(section, %{kind: :library}, uses) do
    case Enum.map(Map.get(uses, section.key, []), & &1.label) do
      [] -> "Not on any page yet."
      [one] -> "On 1 page: #{one}."
      pages -> "On #{length(pages)} pages: #{and_list(pages)}."
    end
  end

  defp uses(_section, _page, _uses), do: nil

  # What a Shared section can swap to: the library's sections this page
  # doesn't already place, and its own.
  defp swap_choices(%{content: %{type: :shared, value: %{key: own}}}, page, library, uses) do
    Enum.reject(library, fn section ->
      section.key != own and
        Enum.any?(Map.get(uses, section.key, []), &(&1.pattern == page.pattern))
    end)
  end

  defp swap_choices(_section, _page, library, _uses), do: library

  defp popover_class do
    [
      "absolute top-full right-4 z-40 mt-2 grid w-80 max-w-[calc(100vw-2rem)] gap-4 bg-bb-edit-ground p-4",
      "text-bb-edit-ink shadow-bb-edit-popover outline-none md:right-6"
    ]
  end

  # The open button's popover: its form, under the section's form, and
  # what it's called, a button or, for a point's, a link.
  defp button({:button, path}, form, content_form, specs) do
    with {:ok, at, part} <- locate(form, specs, path),
         %Phoenix.HTML.Form{} = part_form <- EditorFields.sub_form(content_form, at) do
      name = if part == :link, do: "link", else: "button"

      # What's wrong with its fields, in the same plain words as the strip.
      errors =
        for {field, error} <- part_form.errors,
            do: {field, {plain(Components.translate_error(error)), []}}

      part_form = %{part_form | errors: errors}

      %{path: path, part: part, form: part_form, name: name, title: String.capitalize(name)}
    else
      _gone -> nil
    end
  end

  defp button(_popover, _form, _content_form, _specs), do: nil

  # What Describe shows: the photograph's words as the form has them, or
  # as Describe last sent them, with what's wrong with them.
  defp photo_form(form, sent, key) do
    params =
      Map.merge(
        %{"label" => photo_value(form, :label) || "", "alt" => photo_value(form, :alt) || ""},
        sent || %{}
      )

    errors =
      for {field, message} <- AshPhoenix.Form.errors(form, for_path: [:content, :photo]),
          do: {field, {message, []}}

    to_form(params, as: :photo, id: "photo-#{key}", errors: errors)
  end

  # Adds a list's item, or a part. A button that goes once it has, as Add
  # does when it fills the list, hands the focus to the header.
  defp add_click(spec, field, last?, target) do
    event = if spec[:as] == :list, do: "add_item", else: "add_part"
    push = JS.push(event, value: %{path: field}, target: target)
    if last?, do: JS.focus(push, to: "#section-controls"), else: push
  end

  # What the open section's form says is wrong with a control's change it
  # turned down, field by field, in the order the form has them, with the
  # field's name where it has one, in plain words. One line a field, so
  # the field can point at it by id.
  defp problems(form, specs) do
    errors = form_errors(form)

    for at <- errors |> Enum.map(&elem(&1, 0)) |> Enum.uniq() do
      messages = for {^at, message} <- errors, do: plain(message)
      {at, problem_label(at, specs), Enum.uniq(messages)}
    end
  end

  # A field's errors in plain words, for `<Components.input>`, which draws them.
  defp plain_errors(field),
    do: %{field | errors: Enum.map(field.errors, &{plain(Components.translate_error(&1)), []})}

  # The name of the words at `path`, before why they didn't save.
  defp words_label(path, specs) do
    case EditorFields.words(specs, path) do
      {:ok, _at, spec} -> label_prefix(spec[:label])
      :error -> nil
    end
  end

  defp label_prefix(nil), do: nil
  defp label_prefix(label), do: "#{label}: "

  defp problem_label([:anchor], _specs), do: "Link name"
  defp problem_label([:surface], _specs), do: "Ground"
  defp problem_label([:content, field], specs), do: get_in(specs, [field, :label])
  defp problem_label(_at, _specs), do: nil

  defp setting_error_id(at),
    do: "section-error-" <> Enum.map_join(at -- [:content], "-", &to_string/1)

  defp anchor_hint,
    do:
      "For links like #{Billboard.Site.example_path()}#team. Lowercase letters, numbers, and dashes."

  defp errors?(issues, problems, refused_words),
    do: problems != [] or refused_words != %{} or Enum.any?(issues, &(&1.level == :error))

  # What went wrong with the photograph on its way, or with taking it in.
  defp photo_errors(upload, error) do
    entry_errors = Enum.flat_map(upload.entries, &upload_errors(upload, &1))
    Enum.map(upload_errors(upload) ++ entry_errors, &upload_error/1) ++ List.wrap(error)
  end

  defp upload_error(:too_large), do: "That photograph is over 15 MB. Try a smaller copy."
  defp upload_error(:not_accepted), do: "Use a JPEG, PNG, or WebP photograph."
  defp upload_error(:too_many_files), do: "Choose one photograph."
  defp upload_error(_error), do: "The upload failed. Try again."
end
