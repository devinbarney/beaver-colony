defmodule BeaverColonyWeb.GuideLive.Show do
  @moduledoc """
  One part of the guide.
  """
  use BeaverColonyWeb, :live_view

  alias BeaverColony.Guide

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav}>
      <article id={"guide-#{@article.id}"}>
        <header>
          <p class="guide-article__part">Part {@article.part}</p>
          <h1 class="guide-article__title">{@article.title}</h1>
          <p class="guide-article__description">{@article.description}</p>
        </header>

        <div class="guide-prose">
          {raw(@article.body)}
        </div>

        <nav class="guide-article__pager" aria-label="Other parts">
          <.link :if={@previous} navigate={~p"/guide/#{@previous.id}"}>
            ← Part {@previous.part}: {@previous.title}
          </.link>
          <span :if={!@previous}></span>
          <.link :if={@next} navigate={~p"/guide/#{@next.id}"}>
            Part {@next.part}: {@next.title} →
          </.link>
        </nav>
      </article>
    </Layouts.app>
    """
  end

  # The article comes from the URL, so it's read in handle_params, which runs on mount
  # and on any patch.
  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    article = Guide.get_article!(id)
    {previous, next} = Guide.neighbors(article)

    {:noreply,
     assign(socket, article: article, previous: previous, next: next, page_title: article.title)}
  end
end
