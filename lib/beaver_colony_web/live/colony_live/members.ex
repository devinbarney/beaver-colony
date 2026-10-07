defmodule BeaverColonyWeb.ColonyLive.Members do
  @moduledoc """
  The colony's members and requests to join. For Lodge Keepers and up.

  Lodge Keepers let beavers in and remove Builders. The Dam Developer also changes
  roles. Every button here is a suggestion: `BeaverColony.Colonies` decides.
  """
  use BeaverColonyWeb, :live_view

  on_mount {BeaverColonyWeb.BeaverAuth, {:require, :manage_members}}

  alias BeaverColony.Accounts.Scope
  alias BeaverColony.Colonies
  alias BeaverColony.Colonies.Policy

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav}>
      <.header>
        Members
        <:subtitle>Everyone in {@current_scope.colony.name}.</:subtitle>
      </.header>

      <section :if={@pending != []} id="pending">
        <h2 class="text-lg font-semibold">Asking to join</h2>
        <.table id="pending-requests" rows={@pending}>
          <:col :let={membership} label="Beaver">{membership.beaver.email}</:col>
          <:action :let={membership}>
            <.button phx-click="approve" phx-value-id={membership.id}>Let in</.button>
          </:action>
          <:action :let={membership}>
            <.button phx-click="decline" phx-value-id={membership.id}>Decline</.button>
          </:action>
        </.table>
      </section>

      <.table id="members" rows={@members}>
        <:col :let={membership} label="Beaver">{membership.beaver.email}</:col>
        <:col :let={membership} label="Role">
          <form
            :if={can_change_role?(@current_scope, membership)}
            id={"role-#{membership.id}"}
            phx-change="change_role"
          >
            <input type="hidden" name="membership_id" value={membership.id} />
            <select name="role" class="select select-sm">
              <option
                :for={role <- assignable_roles(@current_scope)}
                value={role}
                selected={role == membership.role}
              >
                {Policy.display_name(role)}
              </option>
            </select>
          </form>
          <span :if={!can_change_role?(@current_scope, membership)}>
            {Policy.display_name(membership.role)}
          </span>
        </:col>
        <:action :let={membership}>
          <.button
            :if={Policy.outranks?(@current_scope.role, membership.role)}
            phx-click="remove"
            phx-value-id={membership.id}
            data-confirm="Remove this beaver from the colony?"
          >
            Remove
          </.button>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Colonies.subscribe_colony_memberships(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Members")
     |> load_members()}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    socket.assigns.current_scope
    |> Colonies.approve_membership(id)
    |> respond(socket, "Welcome to the colony!")
  end

  def handle_event("decline", %{"id" => id}, socket) do
    socket.assigns.current_scope
    |> Colonies.decline_membership(id)
    |> respond(socket, "Request declined.")
  end

  def handle_event("change_role", %{"membership_id" => id, "role" => role}, socket) do
    socket.assigns.current_scope
    |> Colonies.change_role(id, Policy.role_from_param(role))
    |> respond(socket, "Role changed.")
  end

  def handle_event("remove", %{"id" => id}, socket) do
    socket.assigns.current_scope
    |> Colonies.remove_member(id)
    |> respond(socket, "Removed from the colony.")
  end

  # Someone (maybe on another page, maybe another Lodge Keeper) changed the colony's
  # memberships. Read them again.
  @impl true
  def handle_info({:memberships_changed, _colony_id}, socket) do
    {:noreply, load_members(socket)}
  end

  defp respond({:ok, _membership}, socket, message) do
    {:noreply, socket |> put_flash(:info, message) |> load_members()}
  end

  defp respond({:error, :not_found}, socket, _message) do
    {:noreply, socket |> put_flash(:error, "That beaver isn't here anymore.") |> load_members()}
  end

  defp respond({:error, :unauthorized}, socket, _message) do
    {:noreply, put_flash(socket, :error, "Your role can't do that.")}
  end

  defp load_members(socket) do
    scope = socket.assigns.current_scope

    socket
    |> assign(:members, Colonies.list_members(scope))
    |> assign(:pending, Colonies.list_pending(scope))
    # The sidebar's pending badge counts the same requests.
    |> BeaverColonyWeb.Nav.refresh()
  end

  # These only decide which controls to show. The context checks the same rules.
  defp can_change_role?(scope, membership) do
    Scope.can?(scope, :manage_colony) and Policy.outranks?(scope.role, membership.role)
  end

  defp assignable_roles(scope), do: Enum.filter(Policy.roles(), &Policy.outranks?(scope.role, &1))
end
