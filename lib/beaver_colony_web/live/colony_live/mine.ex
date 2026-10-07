defmodule BeaverColonyWeb.ColonyLive.Mine do
  @moduledoc """
  The beaver's own colonies, and a form to found a new one.
  """
  use BeaverColonyWeb, :live_view

  alias BeaverColony.Colonies
  alias BeaverColony.Colonies.{Colony, Policy}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        My colonies
        <:subtitle>Every colony you belong to, and your role in each.</:subtitle>
      </.header>

      <p :if={@memberships == []} id="no-colonies">
        You're not in a colony yet. Found one below.
      </p>

      <.list :if={@memberships != []}>
        <:item :for={membership <- @memberships} title={Policy.display_name(membership.role)}>
          <.link navigate={~p"/colonies/#{membership.colony}"}>{membership.colony.name}</.link>
        </:item>
      </.list>

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
    {:ok,
     socket
     |> assign(:page_title, "My colonies")
     |> assign(:memberships, Colonies.list_memberships(socket.assigns.current_scope))
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

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))
end
