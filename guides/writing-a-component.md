# Writing a component

This guide builds a section of the site's own: a FAQ, a title over
questions and their answers, the answers open or folded under their
questions, with a warning in the editor for a question with no answer
yet. At the end you'll have a component the palette offers, a test that
proves it works on the page and in the editor, and a FAQ on a page.

## What you'll build

A component is a data module and a renderer. The data module, which
does `use Billboard.Component`, is an Ash embedded resource: it says
what a section holds, what the palette calls it, and how the editor
changes it. The renderer, which does `use Billboard.Renderer`, draws it.
A list whose items aren't one of billboard's parts has a part of the
site's own for its items, which does `use Billboard.Part`: the FAQ's
questions are one. The FAQ also has a rule of its own.

## Generate it

<!-- run -->
```bash
mix billboard.gen.component MySite.Sections.Faq --list question --yes
mix test test/my_site/sections/faq_test.exs
```

The generator writes four files, and adds `MySite.Sections.Faq` to the
end of `components:` in `MySite.Billboard`, so the palette offers it.
The skeleton passes its test as written: a title, and a list of
questions, each with a title and some words. The data module:

<!-- site: lib/my_site/sections/faq.ex -->
```elixir
defmodule MySite.Sections.Faq do
  @moduledoc """
  A Faq section: a title, and a list of questions. Its renderer,
  `MySiteWeb.Sections.Faq`, draws it.
  """
  use Billboard.Component

  component do
    key :faq
    label "Faq"
    hint "A title, and a list of questions."
    category :content
    renderer MySiteWeb.Sections.Faq
    placeholder %{title: "Your title", questions: [%{title: "Your first question"}]}

    parts :questions, MySite.Sections.Faq.Question, min: 1, max: 12
  end

  editor do
    words :title, label: "Title", limit: 60

    field :questions,
      as: :list,
      part: MySite.Sections.Faq.Question,
      min: 1,
      max: 12,
      item_label: "question"
  end

  attributes do
    attribute :title, :string, public?: true, constraints: [max_length: 120]
  end
end
```

The part each question is:

<!-- site: lib/my_site/sections/faq/question.ex -->
```elixir
defmodule MySite.Sections.Faq.Question do
  @moduledoc "One question in a Faq section, with a title and some words."
  use Billboard.Part

  part do
    blank %{title: "Your question"}
  end

  editor do
    words :title, label: "Title", limit: 80
    words :body, as: :markdown, label: "Words", limit: 400
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true, constraints: [max_length: 160]
    attribute :body, :string, public?: true, constraints: [max_length: 800]
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
```

The renderer:

<!-- site: lib/my_site_web/sections/faq.ex -->
```elixir
defmodule MySiteWeb.Sections.Faq do
  @moduledoc """
  Draws a Faq section: its title, then each question with its words.
  Open in the editor, each question has its tools, to move or remove it.
  """
  use Billboard.Renderer

  def render(assigns) do
    editing? = Words.editing?(assigns.ctx)

    assigns =
      assign(assigns,
        editing?: editing?,
        count: length(assigns.content.questions),
        spec:
          if(editing?,
            do: EditorFields.narrowed(:faq)[:questions],
            else: []
          )
      )

    ~H"""
    <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
      <h2 :if={@content.title || @editing?} class="bb-heading bb-type-heading text-bb-heading">
        {Words.text(@ctx, "title", @content.title)}
      </h2>
      <div class="bb-measure mt-8">
        <div
          :for={{item, i} <- Enum.with_index(@content.questions)}
          class={["bb-rule-top py-4", @editing? && "bb-edit-item"]}
        >
          <h3 class="bb-item-title bb-type-subheading text-bb-subheading">
            {Words.text(@ctx, "questions.#{i}.title", item.title)}
          </h3>
          <div :if={item.body || @editing?} class="bb-type-body mt-3 text-bb-ink">
            {Words.text(@ctx, "questions.#{i}.body", item.body)}
          </div>
          <Parts.item_tools
            :if={@editing?}
            path="questions"
            index={i}
            count={@count}
            spec={@spec}
          />
        </div>
      </div>
    </section>
    """
  end

  # Its sketch in the palette.
  def glyph(assigns) do
    ~H"""
    <span class="grid flex-1 content-center gap-1 px-1">
      <span class="h-1.5 w-1/2 bg-bb-glyph-ink"></span>
      <span :for={_row <- 1..3} class="flex items-center gap-1.5 border-t border-bb-glyph-line pt-1">
        <span class="h-1 w-2/3 bg-bb-glyph-soft"></span>
      </span>
    </span>
    """
  end
end
```

The fourth file is its test, which [The test](#the-test) explains. The
rest of this guide turns the skeleton into the finished FAQ, one part
at a time.

## The data module

The finished FAQ's `component` section:

<!-- from: guides/examples/lib/my_site/sections/faq.ex#component -->
```elixir
component do
  key :faq
  label "Questions"
  hint "Questions and their answers."
  category :content
  renderer MySiteWeb.Sections.Faq
  rules [MySite.Sections.Faq.UnansweredQuestions]
  placeholder %{title: "Your questions", questions: [%{title: "Your first question"}]}

  parts :questions, MySite.Sections.Faq.Question, min: 1, max: 12
end
```

- `key` is the name a section's content is stored under: every FAQ's
  content is tagged `:faq`. It never changes once there's content, since
  what's stored is tagged with it.
- `label`, `hint`, and `category` are the palette's: the component's
  name, its one line, and the group it's listed in.
  `Billboard.Catalogue.category_label/1` names the group: billboard names
  its own (`:content` is "On the page"), and the site's `palette:`
  answer may name any, or give the component another hint.
- `renderer` names the module that draws it, without depending on it:
  naming it makes no compile-time dependency, so the data module and
  the renderer each recompile alone.
- `rules` is the component's own rules ([A rule](#a-rule)), and
  `placeholder` what a new section starts with
  ([The placeholder](#the-placeholder)).
- `parts :questions, MySite.Sections.Faq.Question` adds the attribute
  that holds the list, as
  `attribute :questions, {:array, MySite.Sections.Faq.Question}, public?: true, allow_nil?: false, default: []`,
  with `min` and `max` as its `min_length` and `max_length`. `part`
  holds one part in the same way.

The FAQ leaves out the options whose defaults suit it:

| Option | What it says | Default |
| --- | --- | --- |
| `kinds` | the kinds of page that may use it | `:all` |
| `max` | how many a page may hold | `nil`, any number |
| `column?` | whether it fits in a column of Two columns | `false` |
| `mirror?` | whether it has image-left and image-right variants | `false` |
| `surface_kind` | its kind in `Billboard.Surfaces`, which says the surfaces it may take | `:page` |
| `surface_from` | where it takes its surface from when it doesn't choose one: `:library`, `:layout`, or, with `nil`, its own or its parent's | `nil` |

`Billboard.Component` says what each option, and each check of them,
does.

## Its fields

<!-- from: guides/examples/lib/my_site/sections/faq.ex#attributes -->
```elixir
attributes do
  attribute :title, :string, public?: true, constraints: [max_length: 120]

  attribute :style, :atom do
    allow_nil? false
    default :open
    public? true
    constraints one_of: [:open, :folded]
  end
end
```

A setting the site may narrow is an attribute with `one_of`: `style` is
`:open` or `:folded`. A site that wants every FAQ folded narrows it in
`use Billboard.Site`, with `options: [faq: [style: [:folded]]]`; the
first value it offers is the one a new FAQ takes, and a save of another
is refused (`Billboard.SiteOptions`). A site narrows the surfaces a
section may take in the same spirit, through `offered:`
([Theming](theming.md)). `max_length` is a hard cap, which the content
refuses past, beside the editor's soft `limit` below.

## A list of questions

The finished part:

<!-- from: guides/examples/lib/my_site/sections/faq/question.ex -->
```elixir
defmodule MySite.Sections.Faq.Question do
  @moduledoc "One question in a FAQ, with its answer."
  use Billboard.Part

  part do
    blank %{title: "Your question"}
  end

  editor do
    words :title, label: "Question", limit: 80
    words :body, as: :markdown, label: "Answer", limit: 400
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true, constraints: [max_length: 160]
    attribute :body, :string, public?: true, constraints: [max_length: 800]
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
```

- `use Billboard.Part` makes an embedded resource the editor can
  change. Its `editor` is the item's, in the same entries a component's
  takes: its words are typed in place, at the item's path, such as
  `questions.0.title`, and any other field it had would be drawn in the
  item's tools.
- `blank` is a new item: what a question starts as when an editor adds
  one. It must pass the part's validations, and its words are filler
  the editor warns about until they're written over.
- `uuid_primary_key :id`, because a part in a list needs one: without
  an id, a change the editor makes to the list, such as adding a
  question, resets every item it didn't touch to its defaults. With
  one, Ash matches each item to the one stored, and updates it.
- `defaults [:read, :destroy, create: :*, update: :*]`, because a part
  needs a primary read, create, and update to be built and changed, and
  one in a list a primary destroy too: Ash destroys an item that's
  dropped from the list, and raises without one.

[Why the rules exist](why-the-rules-exist.md) says more about each.

## How the editor changes it

<!-- from: guides/examples/lib/my_site/sections/faq.ex#editor -->
```elixir
editor do
  field :style, as: :select, label: "Answers", options: [{"Open", :open}, {"Folded", :folded}]
  words :title, label: "Title", limit: 60, accent: true

  field :questions,
    as: :list,
    part: MySite.Sections.Faq.Question,
    min: 1,
    max: 12,
    item_label: "question"
end
```

The entries are drawn in the order they're written. `words` are typed
in place, where the section draws them. `limit` is a soft limit: the
editor counts the words, without their Markdown, against it, and warns
past it, but never blocks. `accent` gives the words a hint about
italics. A `field` is a setting in the controls header, such as
`style`, a note, a part, or a list, such as `questions`, whose items the
open section draws with their tools.

`words` take `as: :text` (the default), for words on one line, or
`as: :markdown`, for words that may run to a few lines. A `field` gives
its `as`:

| `as` | What it edits |
| --- | --- |
| `:select` | one of `options`, each `{label, value}`; `only_on` keeps an option to pages of some kinds |
| `:variants` | the section's layouts, one for each of `options`, in order |
| `:toggle` | a checkbox |
| `:number` | a number, from `min` to `max` |
| `:note` | nothing: it says `text`, with a `link` to where to change what it's about |
| `:binding_note` | nothing: it says the note the section's binding gives (`Billboard.Context`) |
| `:part` | one part, `part`; `except` leaves some of its fields out, and `optional` lets it be taken away |
| `:list` | a list of parts, `part`, from `min` to `max`, with `except` as for one part |
| `:photo` | a photograph, in the shape `ratio` gives, as a Tailwind aspect class |
| `:choices` | several of the site's choices, from the set `from` names (`Billboard.Context`) |
| `:choice` | one of them, from `from`, or none |
| `:surface` | a card's surface, one the site offers cards, or none for its section's |
| `:shared` | one of the shared library's sections |

A part or a list's `part` names one of billboard's parts by its name,
such as `:point` ([Parts reference](parts.md)), or one of the site's own
by its module, as here. Every entry also takes `label`, `hint`,
`hide_when`, which leaves it out while another field holds one of some
values, `bound: :hide`, and `more: true`. A select or variants the site
narrows to one option isn't drawn, since the site has made the choice.

## The look

The finished renderer's `render/1`:

<!-- from: guides/examples/lib/my_site_web/sections/faq.ex#render -->
```elixir
def render(assigns) do
  editing? = Words.editing?(assigns.ctx)

  assigns =
    assign(assigns,
      editing?: editing?,
      folded?: assigns.content.style == :folded and not editing?,
      count: length(assigns.content.questions),
      spec:
        if(editing?,
          do: EditorFields.narrowed(:faq)[:questions],
          else: []
        )
    )

  ~H"""
  <section id={@anchor} data-surface={@ctx.surface} class={Parts.section_class(@ctx)}>
    <h2 :if={@content.title || @editing?} class="bb-heading bb-type-heading text-bb-heading">
      {Words.text(@ctx, "title", @content.title)}
    </h2>
    <div class="bb-measure mt-8">
      <.question
        :for={{question, i} <- Enum.with_index(@content.questions)}
        question={question}
        index={i}
        folded?={@folded?}
        ctx={@ctx}
      >
        <Parts.item_tools :if={@editing?} path="questions" index={i} count={@count} spec={@spec} />
      </.question>
    </div>
  </section>
  """
end
```

and the function component that draws each question, open or folded:

<!-- from: guides/examples/lib/my_site_web/sections/faq.ex#question -->
```elixir
attr :question, :map, required: true
attr :index, :integer, required: true
attr :folded?, :boolean, required: true
attr :ctx, :map, required: true
slot :inner_block

defp question(%{folded?: true} = assigns) do
  ~H"""
  <details class="bb-rule-top py-4">
    <summary class="bb-item-title bb-type-subheading cursor-pointer text-bb-subheading">
      {Words.text(@ctx, "questions.#{@index}.title", @question.title)}
    </summary>
    <div :if={@question.body} class="bb-type-body mt-3 text-bb-ink">
      {Words.text(@ctx, "questions.#{@index}.body", @question.body)}
    </div>
  </details>
  """
end

defp question(assigns) do
  ~H"""
  <div class={["bb-rule-top py-4", Words.editing?(@ctx) && "bb-edit-item"]}>
    <h3 class="bb-item-title bb-type-subheading text-bb-subheading">
      {Words.text(@ctx, "questions.#{@index}.title", @question.title)}
    </h3>
    <div :if={@question.body || Words.editing?(@ctx)} class="bb-type-body mt-3 text-bb-ink">
      {Words.text(@ctx, "questions.#{@index}.body", @question.body)}
    </div>
    {render_slot(@inner_block)}
  </div>
  """
end
```

- The outer element takes `id={@anchor}`, `data-surface={@ctx.surface}`,
  and `Parts.section_class(@ctx)`, which gives it the classes of its
  surface, the page's margin, and its padding.
- `Words.text/4` draws words: as a visitor reads them, and, in the open
  section, as words typed into in place. Its path is the field's,
  through parts and list items: `"title"`, and `"questions.0.title"` for
  the first question's.
- `Words.editing?/1` is true only in the open section. The FAQ shows
  every answer there, folded or not, and an empty answer too, so each
  can be typed into.
- `Parts.item_tools/1` gives each item its buttons, to move it up or
  down and to remove it, unless the list is at its fewest. It reads the
  list's spec, which `EditorFields.narrowed/1` gives by the component's
  key, as the site narrows it.
- A site's renderer may use any class, Tailwind's or the site's own; a
  stock renderer draws only with the theme's, so any site's tokens
  restyle it. The FAQ keeps to the theme's, so it looks like its page.

`use Billboard.Renderer` aliases `Words`, `Parts`, and `EditorFields`,
among the pieces stock sections are drawn from. Details, billboard's
own list of items, is
[the stock example](https://github.com/wallyfoo/billboard/blob/v0.4.0/lib/billboard/sections/details.ex).

## A rule

<!-- from: guides/examples/lib/my_site/sections/faq/unanswered_questions.ex -->
```elixir
defmodule MySite.Sections.Faq.UnansweredQuestions do
  @moduledoc """
  A question with no answer yet is a warning: the editor marks the
  section and says so, and Publish still works.
  """
  @behaviour Billboard.Component.Rule

  import Billboard.Rule, only: [warning: 2]

  @impl true
  def check(section, _page, _shared) do
    case Enum.count(section.content.value.questions, &unanswered?/1) do
      0 -> []
      1 -> [warning(section, "a question has no answer yet")]
      count -> [warning(section, "#{count} questions have no answer yet")]
    end
  end

  defp unanswered?(question), do: is_nil(question.body) or String.trim(question.body) == ""
end
```

The component names it in `rules [MySite.Sections.Faq.UnansweredQuestions]`,
in the `component` section above. A component's rules run on each of
its sections, after billboard's stock rules and before the site's. An
error holds Publish back until it's fixed; a warning, as here, only
advises, and Publish still works. A rule about the whole page, rather
than one section, is the site's, a `Billboard.Rule` in its `rules:`
answer.

## The placeholder

`placeholder` is what a new FAQ starts with, when an editor picks it
from the palette: a title and one question, since the FAQ needs one at
least. It must pass the component's validations, and no rule may find
an error in it, or a new section would arrive broken. A new section is
built from `Billboard.SiteOptions.placeholder/1`, which leaves out a
value the site doesn't offer, so the site's default takes its place. Its words are filler, which the editor
warns about on a page until they're written over, unless the component
says `filler? false`, for a placeholder that reads as finished words.

## The glyph

The renderer's `glyph/1` draws the FAQ's sketch in the palette:

<!-- from: guides/examples/lib/my_site_web/sections/faq.ex#glyph -->
```elixir
def glyph(assigns) do
  ~H"""
  <span class="grid flex-1 content-center gap-1 px-1">
    <span class="h-1.5 w-1/2 bg-bb-glyph-ink"></span>
    <span :for={_row <- 1..3} class="flex items-center gap-1.5 border-t border-bb-glyph-line pt-1">
      <span class="h-1 w-2/3 bg-bb-glyph-soft"></span>
    </span>
  </span>
  """
end
```

It's drawn in the editor's glyph utilities (`bg-bb-glyph-ink`,
`bg-bb-glyph-soft`, and `border-bb-glyph-line`), not the site's colours,
since the palette is the editor's. `Billboard.Sections.Glyph` has the
pieces stock glyphs are drawn from.

## The test

<!-- site: test/my_site/sections/faq_test.exs -->
```elixir
defmodule MySite.Sections.FaqTest do
  use Billboard.ComponentCase, endpoint: MySiteWeb.Endpoint, repo: MySite.Repo

  test "the Faq section works on the page and in the editor" do
    assert_component_works(MySite.Sections.Faq)
  end
end
```

`assert_component_works/2` checks, against the site, that:

1. the site lists the component, and some page may take it;
2. its placeholder builds, and no rule finds an error on its page;
3. a new item in each of its lists, from the part's blank, builds, and
   so does each part it can do without;
4. it draws for a visitor, on its page in the site's layout, with its
   words as they're written and none of the editor's markup;
5. it draws open in the editor, its section editor beside it;
6. every words entry is typed in place, holding its words;
7. every other field draws its control, in the section editor or, for
   an item's tools, a button, and a photograph, in the open section;
8. its glyph draws.

Each failure says what's wrong and how to fix it, and each check can be
run alone. `data:` gives a section that draws rows its data, `context:`
gives the page's context, and `attrs:` gives the content to build in
place of the placeholder; `Billboard.ComponentCase` lists the rest.
`endpoint:` is the site's endpoint, which the open checks mount the
editor on, and `repo:` checks out the database's sandbox for each test.

## Finish it

Put the finished code in place of the skeleton's: the `component`,
`editor`, and `attributes` sections in `lib/my_site/sections/faq.ex`; the
part in `lib/my_site/sections/faq/question.ex`; `render/1`, `question/1`,
and `glyph/1` in `lib/my_site_web/sections/faq.ex`; and the rule in a
new file, `lib/my_site/sections/faq/unanswered_questions.ex`. Run
`mix test`, which passes.

Then open the editor at `/admin/pages`, choose "+ Add a section" below
the hero, and pick Questions, under "On the page". The FAQ arrives
open, with its first question to type over and a warning that it has
no answer yet.
