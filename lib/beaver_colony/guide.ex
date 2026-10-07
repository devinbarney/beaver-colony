defmodule BeaverColony.Guide do
  @moduledoc """
  The article series that explains how this app is built, compiled from the markdown in
  `priv/guide` (one file per part, named `<part>-<slug>.md`).

  Built with NimblePublisher, the same way a Phoenix blog usually is, so the articles
  can move into another app's blog unchanged.
  """

  defmodule Article do
    @moduledoc false
    @enforce_keys [:id, :part, :title, :description, :body]
    defstruct [:id, :part, :title, :description, :body]

    def build(filename, attrs, body) do
      [part, slug] = filename |> Path.basename(".md") |> String.split("-", parts: 2)

      struct!(__MODULE__,
        id: slug,
        part: String.to_integer(part),
        title: Map.fetch!(attrs, :title),
        description: Map.fetch!(attrs, :description),
        body: body
      )
    end
  end

  use NimblePublisher,
    build: Article,
    from: Application.app_dir(:beaver_colony, "priv/guide/*.md"),
    as: :articles,
    highlighters: [:makeup_elixir]

  @articles Enum.sort_by(@articles, & &1.part)

  defmodule NotFoundError do
    defexception [:message, plug_status: 404]
  end

  @doc "Every article, in reading order."
  def list_articles, do: @articles

  @doc "The article with the given id. Raises `NotFoundError` (a 404) if there is none."
  def get_article!(id) do
    Enum.find(@articles, &(&1.id == id)) ||
      raise NotFoundError, "no guide article #{inspect(id)}"
  end

  @doc "The articles before and after `article`, either of which may be `nil`."
  def neighbors(%Article{part: part}) do
    {Enum.find(@articles, &(&1.part == part - 1)), Enum.find(@articles, &(&1.part == part + 1))}
  end
end
