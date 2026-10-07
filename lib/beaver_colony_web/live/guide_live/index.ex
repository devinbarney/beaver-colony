defmodule BeaverColonyWeb.GuideLive.Index do
  @moduledoc """
  The guide's contents: every part of the article series.
  """
  use BeaverColonyWeb, :live_view

  alias BeaverColony.Guide

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav}>
      <.header>
        How Beaver Colony is built
        <:subtitle>
          A multi-tenant Phoenix LiveView app, from zero. The sidebar on the left is the
          one these articles describe: use it to move between them.
        </:subtitle>
      </.header>

      <nav class="guide-contents" id="guide-contents">
        <.link
          :for={article <- @articles}
          navigate={~p"/guide/#{article.id}"}
          class="guide-contents__item"
        >
          <span class="guide-article__part">Part {article.part}</span>
          <span class="guide-contents__title block">{article.title}</span>
          <span class="guide-contents__description block">{article.description}</span>
        </.link>
      </nav>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "The guide", articles: Guide.list_articles())}
  end
end
