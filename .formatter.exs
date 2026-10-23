# Used by "mix format"
locals_without_parens = [
  key: 1,
  label: 1,
  hint: 1,
  category: 1,
  kinds: 1,
  max: 1,
  column?: 1,
  mirror?: 1,
  surface_kind: 1,
  surface_from: 1,
  placeholder: 1,
  part: 2,
  part: 3,
  parts: 2,
  parts: 3,
  min: 1,
  allow_nil?: 1,
  default: 1,
  description: 1,
  page: 2,
  page: 3,
  library: 1
]

[
  import_deps: [:ash, :spark],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
