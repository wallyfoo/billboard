defmodule Billboard.Sections.EditorFields do
  @moduledoc """
  Reads a section's editor fields from its component's `editor` section
  (`Billboard.Component.Info.editor_fields/1`), an ordered keyword list
  of field names and options, for the editor and the renderers. `:as`
  says what each is; `Billboard.Component`'s "How the editor changes it"
  describes each kind, with the options it takes.

  It also draws the fields the page editor doesn't type into on the
  page. The controls header of an open section draws its settings with
  `setting/1`, drawn small, on the editor's blue, in its own ink
  (`--bb-edit-on-accent`), and its layouts with `variant_glyph/1` and
  `variant_label/2`. A button's popover, on the editor's paper, draws
  the button's `:text`, `:select`, and `:note` fields with `fields/1`,
  which counts the words of a field with a `limit` as they're typed
  (`count/3`). They're drawn with the editor's own controls
  (`Billboard.Editor.Components`) and tokens, never the theme's.

  Fields are named by their path inside the content, such as
  `head.action` or `points.1.link`. `resolve/2` turns a path back into a
  field, refusing any the specs don't describe; `words/2` does the same for
  a words field, which the inline editor types into, and `hidden_at?/3`
  says whether the field at a path is left out now, so words a binding
  or a layout leaves out can be refused.
  """
  use Phoenix.Component

  alias Billboard.{Catalogue, Context, Markdown, SiteOptions}
  alias Billboard.Editor.Components
  alias Billboard.EditorLive.Messages
  alias Billboard.Sections.{Glyph, Parts}
  alias Phoenix.LiveView.JS

  @variant_labels %{
    text_only: "Text only",
    media_left: "Photograph left",
    media_right: "Photograph right",
    heading: "Heading",
    quote_left: "Quote left",
    quote_right: "Quote right",
    even: "Even",
    wide_left: "Wide left",
    wide_right: "Wide right"
  }

  # The controls header is a single row, so its words are shorter.
  @short_variant_labels %{
    text_only: "No photo",
    media_left: "Photo left",
    media_right: "Photo right"
  }

  @accent_hint "Wrap one word in asterisks to set it in italic: room for *everyone*."

  @doc """
  The editor fields of a section whose content is `type`, as its
  component's `editor` section declares them
  (`Billboard.Component.Info.editor_fields/1`), before the site narrows
  them.
  """
  @spec specs(atom()) :: keyword()
  def specs(type),
    do: type |> Billboard.Site.component!() |> Billboard.Component.Info.editor_fields()

  @doc """
  The names of every set of choices the site's components and the parts
  pick from (`from:`), for the editor to read once (`Billboard.Context.choices_for/1`).
  """
  @spec choice_names() :: [atom()]
  def choice_names do
    components =
      Enum.flat_map(Billboard.Site.components(), &Billboard.Component.Info.editor_fields/1)

    parts = Enum.flat_map(Parts.parts(), &Parts.editor_fields/1)

    for {_field, spec} <- components ++ parts, from = spec[:from], uniq: true, do: from
  end

  @doc """
  The editor fields of a section whose content is `type`, its
  component's (`specs/1`), narrowed to what the site offers
  (`Billboard.SiteOptions`). It narrows selects, variants, and list
  lengths only:

    * each `:select` keeps only the options the site offers, in the
      component's order;
    * each `:variants` keeps only the layouts the site offers, in the
      component's order;
    * each `:list` the site narrows to a range of lengths has its `max`
      lowered to the range's last, and its `min` raised to the range's
      first, so the editor neither adds an item nor offers to remove one
      that a save would refuse.

  A select or variants left with one option is a choice the site has
  made, which the editor doesn't draw. Every other field, such as a
  `:number` or a `:toggle`, is as the component has it.
  """
  @spec narrowed(atom()) :: keyword()
  def narrowed(type) when is_atom(type) do
    lengths =
      for {field, %Range{} = range} <- SiteOptions.narrowed(type), into: %{}, do: {field, range}

    for {field, spec} <- specs(type) do
      case Keyword.get(spec, :as) do
        :select ->
          {field, Keyword.update!(spec, :options, &SiteOptions.options(type, field, &1))}

        :variants ->
          {field,
           Keyword.update!(spec, :options, fn variants ->
             Enum.filter(variants, &SiteOptions.offers?(type, field, &1))
           end)}

        :list ->
          case Map.fetch(lengths, field) do
            {:ok, first..last//_} -> {field, spec |> lower_max(last) |> raise_min(first)}
            :error -> {field, spec}
          end

        _other ->
          {field, spec}
      end
    end
  end

  defp lower_max(spec, max),
    do: Keyword.update(spec, :max, max, &min(&1, max))

  # A list with no `min` has none, so a range from 0 leaves it as it is.
  defp raise_min(spec, min) do
    if min > Keyword.get(spec, :min, 0),
      do: Keyword.update(spec, :min, min, fn _min -> min end),
      else: spec
  end

  @doc """
  Whether `spec` is left out of `form` now: by its `hide_when`, or, with
  `bound: :hide`, while the section's binding replaces its own words
  (`Billboard.Context.replaces_words?/1`).
  """
  def hidden?(form, spec) do
    Enum.any?(Keyword.get(spec, :hide_when, []), fn {field, values} ->
      to_string(form[field].value) in Enum.map(values, &to_string/1)
    end) or (spec[:bound] == :hide and Context.replaces_words?(form[:bind].value))
  end

  @doc """
  `specs` with each `:binding_note` made the note of the binding `form`
  names, with its link, or left out when that binding says nothing.
  """
  def binding_notes(specs, form) do
    Enum.flat_map(specs, fn
      {field, spec} when is_list(spec) ->
        if spec[:as] == :binding_note,
          do: binding_note(field, form),
          else: [{field, spec}]
    end)
  end

  defp binding_note(field, form) do
    with {_name, opts} <- Context.binding_for(form[:bind].value),
         note when is_binary(note) <- opts[:note] do
      [{field, [as: :note, text: note] ++ Keyword.take(opts, [:link])}]
    else
      _none -> []
    end
  end

  @doc "Whether `spec`'s words are offered under More, by its `more`."
  def more?(spec), do: Keyword.get(spec, :more, false)

  @doc """
  The field a path names (`["points", "1", "link"]`), as the form path
  under the content (`[:points, 1, :link]`), with its spec. Only a `:part`
  or `:list` field resolves, and only through the specs, so a path from
  the browser can't reach anything else.
  """
  @spec resolve(keyword(), [String.t()]) :: {:ok, list(), keyword()} | :error
  def resolve(specs, path), do: find(specs, path, [:part, :list])

  @doc """
  The words field a words path names (`"points.1.body"`), as the form path
  under the content (`[:points, 1, :body]`), with its spec. Only a `:text`
  or `:markdown` field resolves, and only through the specs, as `resolve/2`
  does, so a path from the browser can't reach a setting.
  """
  @spec words(keyword(), String.t()) :: {:ok, list(), keyword()} | :error
  def words(specs, path) when is_binary(path) do
    find(specs, String.split(path, "."), [:text, :markdown])
  end

  # Follows `path` through the specs, into parts and list items, to a field
  # drawn as one of `kinds`.
  defp find(specs, [name | rest], kinds) do
    with {field, spec} <- Enum.find(specs, fn {field, _spec} -> Atom.to_string(field) == name end) do
      descend(field, spec, rest, kinds)
    else
      nil -> :error
    end
  end

  defp find(_specs, [], _kinds), do: :error

  defp descend(field, spec, [], kinds) do
    if Keyword.get(spec, :as, :text) in kinds, do: {:ok, [field], spec}, else: :error
  end

  defp descend(field, spec, [index | rest], kinds) do
    with :list <- spec[:as],
         {index, ""} <- Integer.parse(index),
         [_ | _] <- rest,
         {:ok, path, inner} <- find(Parts.editor_fields(spec[:part]), rest, kinds) do
      {:ok, [field, index | path], inner}
    else
      _not_a_list_item -> descend_part(field, spec, [index | rest], kinds)
    end
  end

  defp descend_part(field, spec, rest, kinds) do
    with :part <- spec[:as],
         {:ok, path, inner} <- find(Parts.editor_fields(spec[:part]), rest, kinds) do
      {:ok, [field | path], inner}
    else
      _other -> :error
    end
  end

  @doc """
  The content's form under the section's `form` (a `Phoenix.HTML.Form`),
  as the editor draws it.
  """
  def content_form(form) do
    [content] = Phoenix.HTML.FormData.to_form(form.source, form, :content, [])
    content
  end

  @doc """
  The form of the part or list item at `at` (`[:points, 1]`, `[:head,
  :action]`) under `form` (a `Phoenix.HTML.Form`), as the editor draws it,
  or nil if `form` hasn't got it.
  """
  def sub_form(form, []), do: form

  def sub_form(form, [field, index | rest]) when is_integer(index) do
    case form |> nested_forms(field) |> Enum.at(index) do
      nil -> nil
      item -> sub_form(item, rest)
    end
  end

  def sub_form(form, [field | rest]) do
    case nested_forms(form, field) do
      [part | _] -> sub_form(part, rest)
      [] -> nil
    end
  end

  defp nested_forms(form, field), do: Phoenix.HTML.FormData.to_form(form.source, form, field, [])

  @doc """
  The AshPhoenix form at `path` under `form` (an `AshPhoenix.Form`), or nil:
  a part's form, or a list's forms.
  """
  def nested(form, []), do: form
  def nested(nil, _path), do: nil
  def nested(forms, [index | rest]) when is_list(forms), do: nested(Enum.at(forms, index), rest)
  def nested(%AshPhoenix.Form{forms: forms}, [field | rest]), do: nested(forms[field], rest)

  @doc """
  Whether the field at `at` under the content (`[:quote, :body]`) is left
  out now: by its own spec, or by that of a part or list holding it, each
  read on its holder's form (`hidden?/2`), as the editor draws them.
  `form` is the content's (`content_form/1`), and `specs` its fields. A
  field the specs don't name, or a holder `form` hasn't got, is left out.
  """
  def hidden_at?(_form, _specs, []), do: true

  def hidden_at?(form, specs, [field | rest]) do
    case List.keyfind(specs, field, 0) do
      {^field, spec} -> hidden?(form, spec) or hidden_within?(form, field, spec, rest)
      nil -> true
    end
  end

  defp hidden_within?(_form, _field, _spec, []), do: false

  defp hidden_within?(form, field, spec, rest) do
    {holder, rest} =
      case {spec[:as], rest} do
        {:list, [index | rest]} when is_integer(index) -> {[field, index], rest}
        _part -> {[field], rest}
      end

    case sub_form(form, holder) do
      %Phoenix.HTML.Form{} = holder -> hidden_at?(holder, Parts.editor_fields(spec[:part]), rest)
      nil -> true
    end
  end

  @doc """
  How many characters `text` has, without its Markdown, measured against
  `limit`: the sentence to show, and whether it's over.

  `max` is the most the field holds, counting its Markdown (its
  attribute's `max_length`), or `nil`. Past it, the field won't save, and
  the sentence says so.
  """
  @spec count(String.t() | nil, pos_integer(), pos_integer() | nil) :: %{
          text: String.t(),
          over: boolean()
        }
  def count(text, limit, max \\ nil) do
    text = String.trim(to_string(text))
    stored = String.length(text)
    length = String.length(Markdown.plain(text))

    cond do
      is_integer(max) and stored > max ->
        %{
          text:
            "Too long to save: #{stored} characters, over #{max}.#{markdown_note(stored, length)}",
          over: true
        }

      length > limit ->
        %{
          text: "#{length} characters, over #{limit}. It still saves, but it may crowd the page.",
          over: true
        }

      true ->
        %{text: "#{length} of #{limit} characters", over: false}
    end
  end

  defp markdown_note(length, length), do: ""
  defp markdown_note(_stored, _length), do: " Its Markdown counts toward this."

  @doc """
  A layout's name: in full, or `:short`, as the controls header says it
  ("Photo left").
  """
  def variant_label(variant, length \\ :full)
  def variant_label(variant, :full), do: Map.fetch!(@variant_labels, variant)

  def variant_label(variant, :short),
    do: Map.get(@short_variant_labels, variant, variant_label(variant))

  @doc """
  What a button that adds one of `spec`'s parts says: "Add a point", "Add
  an action".
  """
  def add_words(spec) do
    item = spec[:item_label] || "item"
    "Add #{article(item)} #{item}"
  end

  defp article(<<first, _rest::binary>>) when first in ~c"aeiou", do: "an"
  defp article(_word), do: "a"

  ## Drawing

  attr :form, Phoenix.HTML.Form, required: true, doc: "a part's form"
  attr :specs, :list, required: true
  attr :ctx, :map, required: true, doc: "the editor's target, and the page"

  @doc """
  The fields `specs` describes, on `form`: a part's `:text`, `:select`,
  and `:note` fields, on the editor's paper, as a button's popover draws
  them.
  """
  def fields(assigns) do
    # A photo and a card's surface are changed in the open section, by the
    # photograph tools and the card's own Ground, so a popover never draws
    # them, and `draw/1` has no clause for either. A point's specs now carry
    # a surface, so handing them here would otherwise crash.
    ~H"""
    <%= for {field, spec} <- @specs, spec[:as] not in [:photo, :surface], not hidden?(@form, spec) do %>
      <.field form={@form} field={field} spec={spec} ctx={@ctx} />
    <% end %>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :field, :atom, required: true
  attr :spec, :list, required: true
  attr :ctx, :map, required: true

  defp field(%{spec: spec} = assigns) do
    assigns
    |> assign(:as, Keyword.get(spec, :as, :text))
    |> assign(:label, spec[:label])
    |> draw()
  end

  defp draw(%{as: :text} = assigns) do
    ~H"""
    <div class="grid gap-2">
      <Components.input
        field={@form[@field]}
        label={@label}
        hint={@spec[:hint] || (@spec[:accent] && accent_hint())}
        phx-debounce="blur"
      />
      <.limit
        :if={@spec[:limit]}
        field={@form[@field]}
        limit={@spec[:limit]}
        max={max_length(@form, @field)}
        target={@ctx.target}
      />
    </div>
    """
  end

  defp draw(%{as: :select} = assigns) do
    assigns =
      assign(assigns, :options, options(assigns.spec, assigns.form[assigns.field], assigns.ctx))

    ~H"""
    <Components.input field={@form[@field]} type="select" label={@label} options={@options} />
    """
  end

  defp draw(%{as: :note} = assigns) do
    ~H"""
    <p class="bb-edit-type-small max-w-[46ch] border-l-2 border-bb-edit-warn pl-3 text-bb-edit-ink">
      {@spec[:text]}
    </p>
    """
  end

  defp draw(%{as: :choices} = assigns) do
    picked = Enum.map(List.wrap(assigns.form[assigns.field].value), &to_string/1) -- [""]

    assigns =
      assign(assigns,
        choices: assigns.ctx.choices[assigns.spec[:from]],
        picked: picked,
        name: assigns.form[assigns.field].name <> "[]",
        errors: errors(assigns.form[assigns.field])
      )

    ~H"""
    <fieldset class="grid gap-1">
      <legend class="bb-edit-type-label mb-2 text-bb-edit-soft">{@label}</legend>
      <%!-- With nothing ticked, the browser sends nothing; this says "none". --%>
      <input type="hidden" name={@name} value="" />
      <label
        :for={{label, value} <- @choices.options}
        data-picked={picked_at(@picked, value)}
        class="flex min-h-11 cursor-pointer items-center gap-3"
      >
        <input
          type="checkbox"
          id={"#{@form[@field].id}-#{value}"}
          name={@name}
          value={value}
          checked={value in @picked}
          class="size-4 accent-bb-edit-ink"
        />
        <span class="bb-edit-type-body text-bb-edit-ink">{label}</span>
        <span
          :if={picked_at(@picked, value)}
          class="bb-edit-type-small flex size-5 items-center justify-center bg-bb-edit-ink text-bb-edit-paper"
        >
          <span aria-hidden="true">{picked_at(@picked, value)}</span>
          <span class="sr-only">(number {picked_at(@picked, value)})</span>
        </span>
      </label>
      <p :if={@choices.options == []} class="bb-edit-type-small text-bb-edit-soft">
        {@choices.none_yet}
      </p>
      <p :if={@errors == []} class="bb-edit-type-small text-bb-edit-soft">
        They show in the order you tick them.
      </p>
      <p :for={error <- @errors} class="bb-edit-type-small text-bb-edit-error">{error}</p>
    </fieldset>
    """
  end

  attr :form, Phoenix.HTML.Form,
    required: true,
    doc: "the content's form, or the section's for one of its own fields"

  attr :field, :atom, required: true
  attr :spec, :list, required: true
  attr :ctx, :map, required: true, doc: "the page, the site's choices, and the editor's target"
  attr :error_id, :string, required: true, doc: "the id of what the issue strip says is wrong"

  attr :chosen, :any,
    default: nil,
    doc:
      "what the setting shows as chosen in place of the field's value; `nil` shows the field's value"

  @doc """
  One setting for the controls header, drawn small, on the editor's blue,
  in its own ink (`--bb-edit-on-accent`): a `:select` as a row of choices when it has three or fewer, and
  as a menu otherwise; a `:toggle`; a `:number`; a `:choice`; `:choices`
  behind a popover named for the field, since it's a list of checkboxes; and
  `:shared`, a menu of the library's sections (`ctx.library`). A field
  with a problem is marked, and points at `error_id`.

  It's named for `form`'s field, so a content field is sent as
  `section[content][columns]`, and a field of the section's own, on the
  section's form, as `section[surface]`. `chosen` stands in for a value
  the field doesn't hold, as a section's surface does for one that names
  none, which is drawn on its kind's default.
  """
  def setting(assigns) do
    field = assigns.form[assigns.field]
    field = if is_nil(assigns.chosen), do: field, else: %{field | value: assigns.chosen}

    assigns
    |> assign(:as, Keyword.get(assigns.spec, :as, :text))
    |> assign(:input, field)
    |> assign(:label, assigns.spec[:label])
    |> assign(:invalid, field.errors != [])
    |> draw_setting()
  end

  @segment [
    "flex min-h-8 cursor-pointer items-center gap-1.5 rounded-[4px] px-2 py-1 pointer-coarse:min-h-11",
    "transition-colors duration-[var(--bb-edit-duration)] ease-bb-edit hover:bg-bb-edit-ground/15",
    "has-checked:bg-bb-edit-ground has-checked:font-semibold has-checked:text-bb-edit",
    "has-focus-visible:outline-2 has-focus-visible:outline-offset-1 has-focus-visible:outline-bb-edit-on-accent"
  ]

  @doc "The classes of one choice in a row of them, in the controls header."
  def segment_class, do: @segment

  defp draw_setting(%{as: :select} = assigns) do
    options = options(assigns.spec, assigns.input, assigns.ctx)

    assigns =
      assign(assigns,
        options: options,
        current: to_string(assigns.input.value),
        row?: length(options) <= 3
      )

    ~H"""
    <fieldset
      :if={@row?}
      id={"section-setting-#{@field}"}
      role="radiogroup"
      class="flex items-center gap-2"
      aria-invalid={@invalid && "true"}
      aria-errormessage={@invalid && @error_id}
    >
      <legend class="sr-only">{@label}</legend>
      <span class="opacity-80" aria-hidden="true">{@label}</span>
      <span class="inline-flex flex-wrap rounded-[6px] bg-bb-edit-ground/12 p-0.5">
        <label :for={{label, value} <- @options} class={segment_class()}>
          <input
            type="radio"
            id={"#{@input.id}-#{value}"}
            name={@input.name}
            value={value}
            checked={@current == to_string(value)}
            class="sr-only"
          />
          {label}
        </label>
      </span>
    </fieldset>
    <label :if={!@row?} id={"section-setting-#{@field}"} class="flex items-center gap-2">
      <span class="opacity-80">{@label}</span>
      <select
        id={@input.id}
        name={@input.name}
        aria-invalid={@invalid && "true"}
        aria-errormessage={@invalid && @error_id}
        class={setting_input_class()}
      >
        {Phoenix.HTML.Form.options_for_select(@options, @input.value)}
      </select>
    </label>
    """
  end

  defp draw_setting(%{as: :choice} = assigns) do
    choices = assigns.ctx.choices[assigns.spec[:from]]
    assigns = assign(assigns, options: [{choices.every, ""} | choices.options])

    ~H"""
    <label id={"section-setting-#{@field}"} class="flex items-center gap-2">
      <span class="opacity-80">{@label}</span>
      <select
        id={@input.id}
        name={@input.name}
        aria-invalid={@invalid && "true"}
        aria-errormessage={@invalid && @error_id}
        class={setting_input_class()}
      >
        {Phoenix.HTML.Form.options_for_select(@options, @input.value)}
      </select>
    </label>
    """
  end

  # The library's sections a Shared section can place: any but another
  # Shared section, which draws nothing. One that has left the library is
  # kept while it's the one placed, so the menu still says so.
  defp draw_setting(%{as: :shared} = assigns) do
    current = to_string(assigns.input.value)

    options =
      for section <- assigns.ctx.library,
          section.content.type != :shared,
          do: {shared_label(section), section.key}

    options =
      if Enum.any?(options, &(elem(&1, 1) == current)),
        do: options,
        else: [{"Gone from the library", current} | options]

    assigns = assign(assigns, :options, options)

    ~H"""
    <label id={"section-setting-#{@field}"} class="flex items-center gap-2">
      <span class="opacity-80">{@label}</span>
      <select
        id={@input.id}
        name={@input.name}
        aria-invalid={@invalid && "true"}
        aria-errormessage={@invalid && @error_id}
        class={[setting_input_class(), "max-w-64"]}
      >
        {Phoenix.HTML.Form.options_for_select(@options, @input.value)}
      </select>
    </label>
    """
  end

  defp draw_setting(%{as: :toggle} = assigns) do
    ~H"""
    <label
      id={"section-setting-#{@field}"}
      class="flex min-h-8 cursor-pointer items-center gap-2 pointer-coarse:min-h-11"
    >
      <input type="hidden" name={@input.name} value="false" />
      <input
        type="checkbox"
        id={@input.id}
        name={@input.name}
        value="true"
        checked={Phoenix.HTML.Form.normalize_value("checkbox", @input.value)}
        aria-invalid={@invalid && "true"}
        aria-errormessage={@invalid && @error_id}
        class="size-4 cursor-pointer accent-bb-edit-on-accent"
      />
      {@label}
    </label>
    """
  end

  defp draw_setting(%{as: :number} = assigns) do
    ~H"""
    <label id={"section-setting-#{@field}"} class="flex items-center gap-2">
      <span class="opacity-80">{@label}</span>
      <input
        type="number"
        id={@input.id}
        name={@input.name}
        value={Phoenix.HTML.Form.normalize_value("number", @input.value)}
        min={@spec[:min]}
        max={@spec[:max]}
        phx-debounce="blur"
        aria-invalid={@invalid && "true"}
        aria-errormessage={@invalid && @error_id}
        class={[setting_input_class(), "w-16"]}
      />
    </label>
    """
  end

  # Ticked in a popover, on the editor's paper, where `draw/1` draws them as a list.
  # The checkboxes stay in the form while it's shut, so a change to
  # any other setting sends them too.
  defp draw_setting(%{as: :choices} = assigns) do
    picked = Enum.map(List.wrap(assigns.input.value), &to_string/1) -- [""]

    # "Groups (2)", ending in the ellipsis, which a screen reader skips.
    summary =
      if picked == [], do: assigns.label, else: "#{assigns.label} (#{length(picked)})"

    assigns = assign(assigns, :summary, summary)

    ~H"""
    <details
      id="section-groups"
      class="relative open:max-sm:basis-full"
      phx-mounted={JS.ignore_attributes(["open"])}
      phx-click-away={JS.remove_attribute("open", to: "#section-groups")}
    >
      <summary class={[
        setting_button_class(),
        "list-none [&::-webkit-details-marker]:hidden",
        @invalid && "outline-2 outline-bb-edit-error"
      ]}>
        <span>{@summary}<span aria-hidden="true">…</span></span>
      </summary>
      <div class="z-40 mt-2 w-72 max-w-[calc(100vw-2rem)] bg-bb-edit-ground p-4 text-bb-edit-ink shadow-[0_8px_24px_rgb(0_0_0/0.18)] sm:absolute sm:top-full sm:right-0">
        <.field form={@form} field={@field} spec={@spec} ctx={@ctx} />
      </div>
    </details>
    """
  end

  @doc """
  The classes of a button in the controls header: a quiet one, or, with
  `:done`, the one on the editor's paper that closes the section.
  """
  def setting_button_class(tone \\ :quiet) do
    [
      "inline-flex min-h-8 cursor-pointer items-center gap-1.5 rounded-[6px] py-1",
      "transition-colors duration-[var(--bb-edit-duration)] ease-bb-edit",
      "focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-bb-edit-on-accent",
      "pointer-coarse:min-h-11",
      if(tone == :done,
        do: "bg-bb-edit-ground px-3.5 font-semibold text-bb-edit hover:bg-bb-edit-ground-alt",
        else: "bg-bb-edit-ground/12 px-2.5 hover:bg-bb-edit-ground/22"
      )
    ]
  end

  defp setting_input_class do
    [
      "min-h-8 cursor-pointer rounded-[4px] border-0 bg-bb-edit-ground/12 px-2 py-1 text-bb-edit-on-accent pointer-coarse:min-h-11",
      "focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-bb-edit-on-accent",
      "aria-invalid:outline-2 aria-invalid:outline-bb-edit-error [&>option]:text-bb-edit-ink"
    ]
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :limit, :integer, required: true
  attr :max, :integer, default: nil, doc: "the most the field holds, if it has a most"
  attr :target, :any, required: true, doc: "the editor, which counts"

  # How much of the soft limit the words use. Past it, a warning, never a
  # block; past the most the field holds, it won't save. The field saves
  # as it loses focus, but the count follows the typing: the hook asks the
  # editor (`count/3`) as the words change.
  defp limit(assigns) do
    assigns = assign(assigns, count(assigns.field.value, assigns.limit, assigns.max))

    ~H"""
    <p
      id={"#{@field.id}-count"}
      phx-hook=".CharacterCount"
      phx-target={@target}
      data-input={@field.id}
      data-limit={@limit}
      data-max={@max}
      data-over-limit={@over}
      class={["bb-edit-type-small", if(@over, do: "text-bb-edit-error", else: "text-bb-edit-soft")]}
    >
      {@text}
    </p>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".CharacterCount">
      // Counts the field's words as they're typed. Markdown isn't counted,
      // so the editor does the counting; the field still saves on blur.
      export default {
        mounted() {
          this.form = this.el.closest("form")
          this.onInput = e => {
            if (e.target.id !== this.el.dataset.input) return
            clearTimeout(this.timer)
            this.timer = setTimeout(() => this.count(), 120)
          }
          this.form?.addEventListener("input", this.onInput)
        },
        // A redraw shows the saved words' count; while the field still
        // holds unsaved typing, count that instead.
        updated() {
          if (document.activeElement?.id === this.el.dataset.input) this.count()
        },
        destroyed() {
          clearTimeout(this.timer)
          this.form?.removeEventListener("input", this.onInput)
        },
        count() {
          const input = document.getElementById(this.el.dataset.input)
          if (!input) return
          const limit = Number(this.el.dataset.limit)
          const max = this.el.dataset.max ? Number(this.el.dataset.max) : null
          this.pushEventTo(this.el, "count", {text: input.value, limit, max}, ({text, over}) => {
            this.el.textContent = text
            this.el.toggleAttribute("data-over-limit", over)
            this.el.classList.toggle("text-bb-edit-error", over)
            this.el.classList.toggle("text-bb-edit-soft", !over)
          })
        }
      }
    </script>
    """
  end

  # The most `field` holds, from its string attribute's `max_length`, if
  # the form is for a resource with one.
  defp max_length(%Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: resource}}, field) do
    case Ash.Resource.Info.attribute(resource, field) do
      %{type: Ash.Type.String, constraints: constraints} -> constraints[:max_length]
      _other -> nil
    end
  end

  defp max_length(_form, _field), do: nil

  attr :variant, :atom, required: true

  @doc """
  A small drawing of a layout, made of the pieces sections' glyphs are
  drawn with (`Billboard.Sections.Glyph`): a block for a photograph or a column,
  bars for the words, and a quote mark. The columns share Two columns'
  widths.
  """
  def variant_glyph(assigns) do
    ~H"""
    <span
      class="flex h-7 w-12 gap-1 border border-bb-glyph-line bg-bb-glyph-paper p-1"
      aria-hidden="true"
    >
      <%= case @variant do %>
        <% :text_only -> %>
          <Glyph.bars class="flex-1" />
        <% :media_left -> %>
          <Glyph.photo class="w-5" /><Glyph.bars class="flex-1" />
        <% :media_right -> %>
          <Glyph.bars class="flex-1" /><Glyph.photo class="w-5" />
        <% :heading -> %>
          <span class="flex flex-1 bg-bb-glyph-ink px-1">
            <Glyph.bars on_dark class="flex-1 justify-items-center" />
          </span>
        <% :quote_left -> %>
          <span class="flex flex-1 items-center gap-0.5 overflow-hidden bg-bb-glyph-ink px-0.5">
            <Glyph.quote_mark class="text-bb-glyph-accent-on-ink" /><Glyph.bars
              on_dark
              class="flex-1"
            />
          </span>
        <% :quote_right -> %>
          <span class="flex flex-1 items-center gap-0.5 overflow-hidden bg-bb-glyph-ink px-0.5">
            <Glyph.bars on_dark class="flex-1" /><Glyph.quote_mark
              side="right"
              class="text-bb-glyph-accent-on-ink"
            />
          </span>
        <% columns when columns in [:even, :wide_left, :wide_right] -> %>
          <Glyph.photo :for={width <- column_widths(columns)} class={width} />
      <% end %>
    </span>
    """
  end

  defp options(spec, field, ctx) do
    current = to_string(field.value)

    only_on = Keyword.get(spec, :only_on, [])

    Enum.filter(spec[:options], fn {_label, value} ->
      case List.keyfind(only_on, value, 0) do
        nil -> true
        {_value, kinds} -> ctx.page.kind in kinds or to_string(value) == current
      end
    end)
  end

  # In the same plain words as the open section's issue strip.
  defp errors(field), do: Enum.map(field.errors, &Messages.plain(Components.translate_error(&1)))

  defp picked_at(picked, value) do
    case Enum.find_index(picked, &(&1 == value)) do
      nil -> nil
      index -> index + 1
    end
  end

  defp shared_label(section) do
    label = Catalogue.label(section.content.type)
    value = section.content.value

    case Map.get(value, :heading) || (Map.get(value, :head) && value.head.heading) do
      heading when is_binary(heading) and heading != "" -> "#{label}: #{Markdown.plain(heading)}"
      _none -> label
    end
  end

  defp accent_hint, do: @accent_hint

  @doc """
  The two columns' widths in a glyph, as flex classes, for Two columns'
  `variant`. The layout drawings (`variant_glyph/1`) and Two columns' own
  glyph use them.
  """
  @spec column_widths(atom()) :: [String.t()]
  def column_widths(:even), do: ["flex-1", "flex-1"]
  def column_widths(:wide_left), do: ["flex-[1.6]", "flex-1"]
  def column_widths(:wide_right), do: ["flex-1", "flex-[1.6]"]
end
