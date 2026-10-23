defmodule Billboard.Site.Info do
  @moduledoc """
  Reads a `use Billboard.Site` module: `pages/1`, its pages, the library
  among them, and `answers/1`, its answers as written, before a test's
  override.
  """
  use Spark.InfoGenerator, extension: Billboard.Site.Dsl, sections: [:pages]

  @doc "Whether `module` does `use Billboard.Site`."
  @spec site?(module()) :: boolean()
  def site?(module) when is_atom(module),
    do: Code.ensure_loaded?(module) and Spark.Dsl.is?(module, Billboard.Site.Base)

  @doc "The site's answers, as `use Billboard.Site` checked them."
  @spec answers(module()) :: keyword()
  def answers(site), do: Spark.Dsl.Extension.get_persisted(site, :billboard_answers)

  @doc "The site's application."
  @spec otp_app(module()) :: atom()
  def otp_app(site), do: Spark.Dsl.Extension.get_persisted(site, :otp_app)
end
