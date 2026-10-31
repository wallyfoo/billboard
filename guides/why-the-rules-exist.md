# Why the rules exist

Billboard checks a component, and the site's answers, as they compile.
This guide takes each rule in turn: what billboard checks, an example
that breaks it and the message it gives, why the rule exists, and the
fix. Every message names its fix, so this guide is for when the fix
isn't enough, and you want to know what the rule protects.

## 1. Every component is tagged

Billboard stores a section's content as `{"type": key, "value":
fields}`, and adds a `component` attribute to every component holding
its key. Without the tag, an edit that names only some of a section's
fields would be read as a new section of whichever type it fits first,
and replace the old one whole. A component can't take the tag away, or
loosen it:

<!-- fails -->
```elixir
defmodule MySite.Sections.Broken do
  use Billboard.Component

  component do
    key :broken
    label "Broken"
    hint "A broken example."
    category :content
  end

  attributes do
    attribute :component, :atom, public?: true
    attribute :title, :string, public?: true
  end
end
```

```text
MySite.Sections.Broken's `component` attribute must be `allow_nil?:
false, default: :broken, constraints: [one_of: [:broken]]`. Take it
out; billboard adds it.
```

The fix is to write no `component` attribute at all.

## 2. A part in a list has an id

When a section's list of parts changes, Ash matches each item it's
given to the one it had by its id. Without ids it can't tell the items
apart, so it rebuilds every item from what the change named, and an
edit to one question's answer would reset every other question's
untouched fields:

<!-- fails -->
```elixir
defmodule MySite.Sections.Broken.Item do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :title, :string, public?: true
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end

defmodule MySite.Sections.Broken do
  use Billboard.Component

  component do
    key :broken
    label "Broken"
    hint "A broken example."
    category :content
    parts :items, MySite.Sections.Broken.Item
  end
end
```

```text
MySite.Sections.Broken.Item sits in a list, so it needs
`uuid_primary_key :id`: without one, a list change rebuilds every item
from its params alone.
```

`use Billboard.Part` gives a part its id, and its actions, so a part
written with it never breaks this rule or the next.

## 3. A part has a primary destroy action

Ash destroys a part when it's dropped from a list, or when an optional
part is cleared, and it does so through the part's primary destroy
action:

<!-- fails -->
```elixir
defmodule MySite.Sections.Broken.Item do
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true
  end

  actions do
    defaults [:read, create: :*, update: :*]
  end
end

defmodule MySite.Sections.Broken do
  use Billboard.Component

  component do
    key :broken
    label "Broken"
    hint "A broken example."
    category :content
    parts :items, MySite.Sections.Broken.Item
  end
end
```

```text
MySite.Sections.Broken.Item has no destroy action, and Ash destroys a
part when it's dropped from a list or cleared. Add `defaults [:read, :destroy,
create: :*, update: :*]` to its actions.
```

## 4. The placeholder holds only what create accepts

A new section is built from its component's placeholder, through the
component's create action. A field create doesn't accept would be
refused, and the editor couldn't add the section at all:

<!-- fails -->
```elixir
defmodule MySite.Sections.Broken do
  use Billboard.Component

  component do
    key :broken
    label "Broken"
    hint "A broken example."
    category :content
    placeholder %{title: "Your title"}
  end

  attributes do
    attribute :title, :string
  end
end
```

```text
`:title` is in the placeholder, but MySite.Sections.Broken's create
doesn't accept it, and a new section is built through create. Make the
attribute `public?: true`, or take it out of the placeholder.
```

The placeholder must also pass the component's own validations, which
no compile-time check can run; `assert_component_works/2` builds it,
so a component's test catches a placeholder that's too long or missing
a field it needs.

## 5. Editor entries edit what they say they do

Each entry in `editor` edits an attribute of the component, of the
right kind: words are strings, since the editor types them in place;
a list or a part names the part it holds, since the editor draws the
part's own fields; and a choice names its set of choices. A component
holds one set of several choices (`:choices`) at most, since the editor
keeps one a section:

<!-- fails -->
```elixir
defmodule MySite.Sections.Broken do
  use Billboard.Component

  component do
    key :broken
    label "Broken"
    hint "A broken example."
    category :content
  end

  editor do
    words :count, label: "Count"
  end

  attributes do
    attribute :count, :integer, public?: true
  end
end
```

```text
`:count` is words in `editor`, but it isn't a string. Make it a
`field`, or `:count` a string attribute
```

## 6. A component's surface kind can be drawn

A section is drawn on a ground of its own, a surface of the kind its
component names. `:card` is the kind of a card inside a section, so a
section of that kind would have no ground:

<!-- fails -->
```elixir
defmodule MySite.Sections.Broken do
  use Billboard.Component

  component do
    key :broken
    label "Broken"
    hint "A broken example."
    category :content
    surface_kind :card
  end
end
```

```text
MySite.Sections.Broken's `surface_kind` is `:card`, but `:card` is the
kind of a card inside a section, not of a section, and a section needs
a ground of its own. Use `:page`, `:stand_out`, or another kind the
site offers its sections.
```

## 6a. A renderer is a module, and the actions are all there

A component's `renderer` is checked once the component has compiled,
so naming it makes no compile-time dependency between the two, and a
typo in it is still caught:

<!-- fails -->
```elixir
defmodule MySite.Sections.Broken do
  use Billboard.Component

  component do
    key :broken
    label "Broken"
    hint "A broken example."
    category :content
    renderer MySiteWeb.Sections.Brokn
  end
end
```

```text
`renderer` names MySiteWeb.Sections.Brokn, which isn't a module. Define
it, with `use Billboard.Renderer`, or name the module that draws
MySite.Sections.Broken
```

A component needs a primary read, create, update, and destroy action.
Billboard adds all four, unless the component writes its own
`defaults`, which are kept as written. One that leaves a type out would
compile, then fail the first time a section needs it:

<!-- fails -->
```elixir
defmodule MySite.Sections.Broken do
  use Billboard.Component

  component do
    key :broken
    label "Broken"
    hint "A broken example."
    category :content
  end

  actions do
    defaults [:read, create: :*, update: :*]
  end
end
```

```text
MySite.Sections.Broken has no primary destroy action, and Ash destroys
a section's component when it's replaced. Add `:destroy` to its
`defaults`, or take `defaults` out; billboard adds them.
```

## 7. The site's answers

`use Billboard.Site` checks its answers against one another, and
against the components they name. Each of these is a mistake a site
would otherwise find only when a page or the editor reached it:

<!-- fails -->
```elixir
defmodule MySite.Broken do
  use Billboard.Site,
    otp_app: :my_site,
    repo: MySite.Repo,
    pubsub: MySite.PubSub,
    domain: MySite.Pages,
    resources: [
      page: MySite.Pages.Page,
      version: MySite.Pages.Version,
      section: MySite.Pages.Section,
      content: MySite.Pages.Content
    ],
    components: [Billboard.Components.Hero, MySite.Sections.Faq, MySite.Sections.Faq]

  pages do
    page "/", "Home", kind: :free
  end
end
```

```text
MySite.Broken lists MySite.Sections.Faq twice in `components:`. Take
one out.
```

The site is also refused, each with a message naming its fix, for:

- two components with one key, since a key is what content is stored
  under;
- a page named twice, a page pattern that doesn't start with `/`, a
  page whose kind is `:library`, and a fixed section the site lists no
  component for;
- a hint in `palette: [hints: …]`, or a key in `kinds:`, for a
  component the site doesn't list, a hint or a `kinds:` key given twice,
  and a page kind in `kinds:` that no page has;
- an `actions:`, `context:`, `data:`, or `layout:` that isn't a module,
  or doesn't define its callbacks;
- a context that gives `choices/1` without `choice_sets/0`, or the
  other way round.

An answer of the wrong shape, such as a `kinds:` that isn't a keyword
list of page kinds, raises an `ArgumentError` as the site module
compiles, naming the shape it wants, rather than a verifier's warning.

## 8. Settings the site stops offering

A site's options narrow what a field may hold. When the site stops
offering a value, a section that holds it isn't refused: the value is
checked only when it changes, so the section keeps saving its other
fields, and it's drawn with the site's default meanwhile.
`test/billboard/site_options_test.exs` shows it: an updated component
keeps a value the site has stopped offering while it saves another
field, and `resolve/3` gives the site's default for it.

## 9. Keys are forever

A component's key is what its sections' content is stored under. Change
it, and every stored section of the old key no longer names a component
the site has. Rename a component's module, label, or hint as you like,
but keep its key, or migrate the stored sections to the new one.

## 10. Verifiers report through compile warnings

Every check in rules 1 to 7, but the malformed answer, is a Spark
verifier, which runs once its module has compiled. It reports through
a compile warning, not an error, so a broken component compiles, and
fails later. Compile with `--warnings-as-errors`, as phx.new's
`precommit` alias does, to stop on the warning.
`test/integration/guides_test.exs` builds a site from the guides and
compiles it so.
