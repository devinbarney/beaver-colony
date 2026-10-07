defmodule BeaverColonyWeb.ColonyLive.Mine do
  @moduledoc """
  The beaver's own colonies, the colonies they could join, and a form to found a new
  one.
  """
  use BeaverColonyWeb, :live_view

  alias BeaverColony.Colonies
  alias BeaverColony.Colonies.{Colony, Policy}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav}>
      <.header>
        My colonies
        <:subtitle>Every colony you belong to, and your role in each.</:subtitle>
      </.header>

      <p :if={@memberships == []} id="no-colonies">
        You're not in a colony yet. Join one or found your own.
      </p>

      <.list :if={@memberships != []}>
        <:item :for={membership <- @memberships} title={Policy.display_name(membership.role)}>
          <.link navigate={~p"/colonies/#{membership.colony}"}>{membership.colony.name}</.link>
        </:item>
      </.list>

      <section :if={@other_colonies != []} id="other-colonies">
        <h2 class="text-lg font-semibold">Other colonies</h2>
        <.table id="joinable" rows={@other_colonies}>
          <:col :let={{colony, _status}} label="Colony">{colony.name}</:col>
          <:action :let={{colony, status}}>
            <span :if={status == :pending}>Waiting for a Lodge Keeper</span>
            <.button :if={status != :pending} phx-click="join" phx-value-id={colony.id}>
              Ask to join
            </.button>
          </:action>
        </.table>
      </section>

      <.form for={@form} id="colony-form" phx-change="validate" phx-submit="found">
        <.input
          field={@form[:name]}
          type="text"
          label="Found a colony"
          placeholder="Willamette Colony"
        />
        <.button variant="primary" phx-disable-with="Founding...">Found colony</.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Colonies.subscribe_my_memberships(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "My colonies")
     |> load_colonies()
     |> assign_form(Colonies.change_colony(%Colony{}))}
  end

  @impl true
  def handle_event("validate", %{"colony" => params}, socket) do
    changeset = Colonies.change_colony(%Colony{}, params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("found", %{"colony" => params}, socket) do
    case Colonies.create_colony(socket.assigns.current_scope, params) do
      {:ok, colony} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{colony.name} is founded. You're its Dam Developer.")
         |> push_navigate(to: ~p"/colonies/#{colony}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("join", %{"id" => colony_id}, socket) do
    case Colonies.request_to_join(socket.assigns.current_scope, colony_id) do
      {:ok, _membership} ->
        {:noreply, socket |> put_flash(:info, "Asked to join.") |> load_colonies()}

      {:error, _reason} ->
        {:noreply, socket |> put_flash(:error, "Couldn't ask to join.") |> load_colonies()}
    end
  end

  # Let in, removed or given a new role somewhere: show the lists as they are now.
  @impl true
  def handle_info({:membership_changed, _colony_id}, socket) do
    {:noreply, load_colonies(socket)}
  end

  defp load_colonies(socket) do
    scope = socket.assigns.current_scope

    socket
    |> assign(:memberships, Colonies.list_memberships(scope))
    |> assign(:other_colonies, Colonies.list_other_colonies(scope))
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))
end
