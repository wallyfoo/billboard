defmodule Billboard.Site.Dsl do
  @moduledoc """
  The Spark extension behind `use Billboard.Site`: its `pages` section,
  the transformer that adds the library when the site doesn't write it,
  and the verifiers that check the site's answers and pages.
  `Billboard.Site` documents them.
  """

  @page %Spark.Dsl.Entity{
    name: :page,
    describe: "A page the builder knows, at a route pattern.",
    examples: [~s(page "/services/:slug", "A service", kind: :service)],
    target: Billboard.Directory.Page,
    args: [:pattern, :label],
    schema: [
      pattern: [type: :string, required: true, doc: "Its route pattern, such as \"/\"."],
      label: [type: :string, required: true, doc: "What the admin calls it."],
      kind: [
        type: :atom,
        required: true,
        doc: "The site's kind of page, which decides its components."
      ],
      fixed: [type: {:list, :atom}, doc: "The sections a fixed page must have, in order, by key."],
      title: [type: :string, doc: "Its browser title, when that isn't the hero's heading."]
    ]
  }

  @library %Spark.Dsl.Entity{
    name: :library,
    describe: "The shared-sections library: the page with no pattern, whose kind is `:library`.",
    examples: [~s(library "Shared sections")],
    target: Billboard.Directory.Page,
    args: [:label],
    auto_set_fields: [pattern: nil, kind: :library],
    schema: [label: [type: :string, required: true, doc: "What the admin calls it."]]
  }

  @pages %Spark.Dsl.Section{
    name: :pages,
    describe: "The pages the builder knows, in the order the admin lists them.",
    entities: [@page, @library]
  }

  use Spark.Dsl.Extension,
    sections: [@pages],
    transformers: [Billboard.Site.Transformers.AddLibrary],
    verifiers: [
      Billboard.Site.Verifiers.VerifyComponents,
      Billboard.Site.Verifiers.VerifyPages,
      Billboard.Site.Verifiers.VerifyResources
    ]
end
