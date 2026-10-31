defmodule Billboard.UsageRulesTest do
  @moduledoc """
  The usage rules name only modules and functions billboard has, and
  every token the theme reads, every utility it defines, and every kind
  of editor field.
  """
  use ExUnit.Case, async: true

  @files ["usage-rules.md" | Path.wildcard("usage-rules/*.md")]

  test "every module and function they name exists" do
    for file <- @files,
        [_ | names] <-
          Regex.scan(
            ~r/`(Billboard(?:\.[A-Z]\w*)*)(?:\.([a-z_]+[?!]?)\/(\d))?`/,
            File.read!(file)
          ) do
      [module | rest] = names
      module = Module.concat([module])
      assert Code.ensure_loaded?(module), "#{file} names #{inspect(module)}, which doesn't exist"

      with [fun, arity] <- rest do
        fun = String.to_atom(fun)
        arity = String.to_integer(arity)

        assert function_exported?(module, fun, arity) or macro_exported?(module, fun, arity),
               "#{file} names #{inspect(module)}.#{fun}/#{arity}, which doesn't exist"
      end
    end
  end

  test "the theme rules name every token the theme reads" do
    text = File.read!("usage-rules/theme.md")

    for token <- Billboard.Test.Theme.tokens("assets/css/theme.css"),
        do: assert(text =~ "`#{token}`", "usage-rules/theme.md leaves out #{token}")
  end

  test "the theme rules name every utility the theme defines" do
    text = File.read!("usage-rules/theme.md")

    for [_, utility] <- Regex.scan(~r/@utility ([a-z0-9-]+)/, File.read!("assets/css/theme.css")),
        do: assert(text =~ "`#{utility}`", "usage-rules/theme.md leaves out #{utility}")
  end

  test "the components rules name every kind of editor field" do
    text = File.read!("usage-rules/components.md")
    field = Enum.find(Billboard.Component.Dsl.editor_section().entities, &(&1.name == :field))
    {:in, kinds} = field.schema[:as][:type]

    for as <- kinds, do: assert(text =~ "`#{inspect(as)}`", "components.md leaves out #{as}")
  end
end
