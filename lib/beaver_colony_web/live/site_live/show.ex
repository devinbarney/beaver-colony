defmodule BeaverColonyWeb.SiteLive.Show do
  use BeaverColonyWeb, :live_view

  on_mount {BeaverColonyWeb.BeaverAuth, {:require, :view_sites}}

  alias BeaverColony.Accounts.Scope
  alias BeaverColony.Building

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav}>
      <.header>
        {@site.name}
        <:subtitle>A build site of {@current_scope.colony.name}.</:subtitle>
        <:actions>
          <.button navigate={~p"/colonies/#{@current_scope.colony.id}/sites"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            :if={Scope.can?(@current_scope, :manage_sites)}
            variant="primary"
            navigate={~p"/colonies/#{@current_scope.colony.id}/sites/#{@site}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Edit site
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@site.name}</:item>
        <:item title="River mile">{@site.river_mile}</:item>
        <:item title="Notes">{@site.notes}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Building.subscribe_sites(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Build site")
     |> assign(:site, Building.get_site!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %BeaverColony.Building.Site{id: id} = site},
        %{assigns: %{site: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :site, site)}
  end

  def handle_info(
        {:deleted, %BeaverColony.Building.Site{id: id}},
        %{assigns: %{site: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "The current site was deleted.")
     |> push_navigate(to: ~p"/colonies/#{socket.assigns.current_scope.colony.id}/sites")}
  end

  def handle_info({type, %BeaverColony.Building.Site{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
