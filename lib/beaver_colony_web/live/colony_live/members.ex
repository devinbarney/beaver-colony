defmodule BeaverColonyWeb.ColonyLive.Members do
  @moduledoc """
  The colony's members and their roles. For Lodge Keepers and up.
  """
  use BeaverColonyWeb, :live_view

  on_mount {BeaverColonyWeb.BeaverAuth, {:require, :manage_members}}

  alias BeaverColony.Colonies
  alias BeaverColony.Colonies.Policy

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Members
        <:subtitle>Everyone in {@current_scope.colony.name}.</:subtitle>
      </.header>

      <.table id="members" rows={@members}>
        <:col :let={membership} label="Beaver">{membership.beaver.email}</:col>
        <:col :let={membership} label="Role">{Policy.display_name(membership.role)}</:col>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Members")
     |> assign(:members, Colonies.list_members(socket.assigns.current_scope))}
  end
end
