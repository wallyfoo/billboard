defmodule Billboard.Editor.Components do
  @moduledoc """
  The page editor's own controls: its buttons, its inputs, its messages,
  and its icon. The editor draws its own controls, from its own
  `--bb-edit-*` tokens (`editor.css`), so they look the same on every
  site and never take on the site's fonts or colours, as the theme's
  `bb-type-*` roles and `bb-*` colours would.

  A focused button or checkbox is ringed in the editor's blue
  (`--bb-edit-accent`), not in the theme's focus colour, which the
  surface sets and which can be all but invisible on it, as on a dark
  hero. A focused text field, select, or textarea is marked by its
  underline, in the editor's ink, instead.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  A message: a paper bar with a hairline and the editor's ink on its
  left edge, or the error colour for an error. A click closes it.
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-4 right-4 left-4 z-50 sm:left-auto sm:w-96"
      {@rest}
    >
      <div class={[
        "flex items-start gap-3 border border-bb-edit-line border-l-2 bg-bb-edit-paper px-4 py-3 cursor-pointer",
        @kind == :info && "border-l-bb-edit-ink",
        @kind == :error && "border-l-bb-edit-error"
      ]}>
        <div class="flex-1">
          <p :if={@title} class="bb-edit-type-label text-bb-edit-ink">{@title}</p>
          <p class={[
            "bb-edit-type-small",
            @kind == :error && "text-bb-edit-error",
            @title && "mt-2"
          ]}>
            {msg}
          </p>
        </div>
        <button type="button" class="min-h-6 text-bb-edit-soft" aria-label="close">
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  The editor's messages: an info and an error message from the flash, and
  the two that say the connection has gone and is coming back.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="Connection lost"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Reconnecting <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Something went wrong"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Reconnecting <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  A button, or a link drawn as one when `href`, `navigate`, or `patch` is
  given. `primary` is filled with the editor's ink, and `secondary` is an
  outline that fills on hover.

  ## Examples

      <.button>Done</.button>
      <.button variant="secondary" disabled>Discard</.button>
  """
  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled target rel form type)

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary secondary), default: "primary"
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :classes, [
        "bb-edit-type-button inline-flex min-h-11 items-center justify-center gap-2 border px-6",
        "cursor-pointer transition-colors duration-[var(--bb-edit-duration)] ease-bb-edit",
        "disabled:cursor-not-allowed disabled:border-bb-edit-line disabled:bg-bb-edit-line disabled:text-bb-edit-disabled",
        "phx-submit-loading:opacity-75",
        focus_ring(),
        skin(assigns.variant),
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@classes} {@rest}>
        <span class="inline-block">{render_slot(@inner_block)}</span>
      </.link>
      """
    else
      ~H"""
      <button class={@classes} {@rest}>
        <span class="inline-block">{render_slot(@inner_block)}</span>
      </button>
      """
    end
  end

  # The editor's focus ring, in its blue, for the controls that draw no
  # focus of their own.
  defp focus_ring,
    do: "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-bb-edit"

  defp skin("primary"),
    do:
      "border-bb-edit-ink bg-bb-edit-ink text-bb-edit-paper hover:border-bb-edit-ink-strong hover:bg-bb-edit-ink-strong"

  defp skin("secondary"),
    do:
      "border-bb-edit-secondary bg-transparent text-bb-edit-secondary hover:bg-bb-edit-secondary hover:text-bb-edit-paper"

  @doc """
  An underlined form field with a small caps label above it, and its hint
  or its errors beneath.

  ## Examples

      <.input field={@form[:heading]} label="Heading" hint="A few words" />
      <.input field={@form[:layout]} type="select" label="Layout" options={@options} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :hint, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "extra classes for the field wrapper"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class={["grid content-start gap-2", @class]}>
      <label class="flex min-h-11 cursor-pointer items-center gap-3">
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={["size-4 accent-bb-edit-ink", focus_ring()]}
          {@rest}
        />
        <span class="bb-edit-type-body text-bb-edit-ink">{@label}</span>
      </label>
      <.field_note hint={@hint} errors={@errors} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class={["grid content-start gap-2", @class]}>
      <label :if={@label} for={@id} class="bb-edit-type-label text-bb-edit-soft">{@label}</label>
      <select
        id={@id}
        name={@name}
        class={[field_classes(@errors), "cursor-pointer appearance-none"]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.field_note hint={@hint} errors={@errors} />
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class={["grid content-start gap-2", @class]}>
      <label :if={@label} for={@id} class="bb-edit-type-label text-bb-edit-soft">{@label}</label>
      <textarea id={@id} name={@name} class={[field_classes(@errors), "resize-y"]} {@rest}>{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.field_note hint={@hint} errors={@errors} />
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class={["grid content-start gap-2", @class]}>
      <label :if={@label} for={@id} class="bb-edit-type-label text-bb-edit-soft">{@label}</label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[field_classes(@errors), "min-h-11"]}
        {@rest}
      />
      <.field_note hint={@hint} errors={@errors} />
    </div>
    """
  end

  defp field_classes(errors) do
    [
      "bb-edit-type-body w-full rounded-none border-0 border-b bg-transparent px-0 pt-1 pb-3 text-bb-edit-ink",
      "placeholder:text-bb-edit-soft/70 outline-none transition-colors duration-[var(--bb-edit-duration-ui)] ease-bb-edit",
      "focus:border-bb-edit-ink focus-visible:outline-none",
      "not-placeholder-shown:border-bb-edit-ink",
      "read-only:text-bb-edit-soft disabled:bg-bb-edit-line disabled:text-bb-edit-disabled",
      if(errors == [], do: "border-bb-edit-faint", else: "border-bb-edit-error")
    ]
  end

  attr :hint, :string, default: nil
  attr :errors, :list, default: []

  defp field_note(assigns) do
    ~H"""
    <p :for={msg <- @errors} class="bb-edit-type-small text-bb-edit-error">{msg}</p>
    <p :if={@errors == [] && @hint} class="bb-edit-type-small text-bb-edit-soft">{@hint}</p>
    """
  end

  @doc "A Heroicon, such as `hero-x-mark-mini`: see `Billboard.Sections.Icons.icon/1`."
  defdelegate icon(assigns), to: Billboard.Sections.Icons

  @doc "Shows the element at `selector`, fading it in."
  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 200,
      transition: {"transition-opacity ease-bb-edit duration-200", "opacity-0", "opacity-100"}
    )
  end

  @doc "Hides the element at `selector`, fading it out."
  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition: {"transition-opacity ease-bb-edit duration-200", "opacity-100", "opacity-0"}
    )
  end

  @doc """
  An error's message, its `%{name}`s filled from its options, as Gettext
  fills a message it has no translation of. A `%{name}` its options don't
  fill is left as written, where Gettext raised
  `Gettext.MissingBindingsError`.
  """
  def translate_error({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, message ->
      String.replace(message, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
