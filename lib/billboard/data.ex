defmodule Billboard.Data do
  @moduledoc """
  What a site reads for the sections that draw rows from outside the
  builder, such as reviews and news. A site names its module in
  `use Billboard.Site`, as `data: MySite.Pages.Data`:

      defmodule MySite.Pages.Data do
        @behaviour Billboard.Data

        alias Billboard.Components.{News, Reviews}

        @impl true
        def fetch(%Reviews{}, _context, loaded),
          do: Billboard.Data.once(loaded, :reviews, &MySite.list_reviews!/0)

        def fetch(%News{limit: limit}, _context, loaded),
          do: Billboard.Data.once(loaded, {:news, limit}, fn -> MySite.latest_news!(limit) end)

        def fetch(_content, _context, _loaded), do: :none
      end

  `Billboard.Resolver` calls `fetch/3` for every one of a page's
  sections, whatever its component, so the module ends with a catch-all
  clause that returns `:none`. It's given a section's content, the
  page's context (the map `Billboard.Context` describes), and what this
  page has read already, and returns `{:ok, value, loaded}`, the
  section's data with what it read, or `:none` for a section that draws
  none. Anything else raises `ArgumentError`, naming the section.

  `once/3` reads a thing the first time a page asks for it, and reuses
  it after, as the section's data: it returns `{:ok, value, loaded}`.
  `cached/3` does the same but returns `{value, loaded}`, for a section
  whose data is made from a shared read. Here news sections of any
  limit share one read of the six latest posts, the most a section
  shows, where `once/3` above reads once per limit:

      def fetch(%News{limit: limit}, _context, loaded) do
        {posts, loaded} = Billboard.Data.cached(loaded, :news, fn -> MySite.latest_news!(6) end)
        {:ok, Enum.take(posts, limit), loaded}
      end

  Each stock component that draws rows documents them:
  `Billboard.Sections.Reviews` and `Billboard.Sections.News`.
  """

  @doc "A section's data, and what's been read. See the moduledoc."
  @callback fetch(content :: struct(), context :: map(), loaded :: map()) ::
              {:ok, term(), map()} | :none

  @doc "`{:ok, value, loaded}`, reading `what` with `read` only if it hasn't been read."
  @spec once(map(), term(), (-> term())) :: {:ok, term(), map()}
  def once(loaded, what, read) do
    {value, loaded} = cached(loaded, what, read)
    {:ok, value, loaded}
  end

  @doc "`{value, loaded}`, reading `what` with `read` only if it hasn't been read."
  @spec cached(map(), term(), (-> term())) :: {term(), map()}
  def cached(loaded, what, read) do
    case loaded do
      %{^what => value} ->
        {value, loaded}

      _ ->
        value = read.()
        {value, Map.put(loaded, what, value)}
    end
  end
end
