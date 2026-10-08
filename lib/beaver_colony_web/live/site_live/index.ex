defmodule BeaverColonyWeb.SiteLive.Index do
  use BeaverColonyWeb, :live_view

  on_mount {BeaverColonyWeb.BeaverAuth, {:require, :view_sites}}

  alias BeaverColony.Accounts.Scope
  alias BeaverColony.Building

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav}>
      <.header>
        Build sites
        <:subtitle>Where along the river {@current_scope.colony.name} can build.</:subtitle>
        <:actions :if={@can_manage}>
          <.button variant="primary" navigate={~p"/colonies/#{@current_scope.colony.id}/sites/new"}>
            <.icon name="hero-plus" /> New build site
          </.button>
        </:actions>
      </.header>

      <.table
        id="sites"
        rows={@streams.sites}
        row_click={
          fn {_id, site} -> JS.navigate(~p"/colonies/#{@current_scope.colony.id}/sites/#{site}") end
        }
      >
        <:col :let={{_id, site}} label="Name">{site.name}</:col>
        <:col :let={{_id, site}} label="River mile">{site.river_mile}</:col>
        <:col :let={{_id, site}} label="Notes">{site.notes}</:col>
        <:action :let={{_id, site}}>
          <div class="sr-only">
            <.link navigate={~p"/colonies/#{@current_scope.colony.id}/sites/#{site}"}>Show</.link>
          </div>
          <.link
            :if={@can_manage}
            navigate={~p"/colonies/#{@current_scope.colony.id}/sites/#{site}/edit"}
          >
            Edit
          </.link>
        </:action>
        <:action :let={{id, site}} :if={@can_manage}>
          <.link
            phx-click={JS.push("delete", value: %{id: site.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Building.subscribe_sites(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Build sites")
     |> assign(:can_manage, Scope.can?(socket.assigns.current_scope, :manage_sites))
     |> stream(:sites, list_sites(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    site = Building.get_site!(socket.assigns.current_scope, id)

    case Building.delete_site(socket.assigns.current_scope, site) do
      {:ok, _} -> {:noreply, stream_delete(socket, :sites, site)}
      {:error, :unauthorized} -> {:noreply, put_flash(socket, :error, "Your role can't do that.")}
    end
  end

  @impl true
  def handle_info({type, %BeaverColony.Building.Site{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :sites, list_sites(socket.assigns.current_scope), reset: true)}
  end

  defp list_sites(current_scope) do
    Building.list_sites(current_scope)
  end
end
