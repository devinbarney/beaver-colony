defmodule BeaverColonyWeb.ColonyLive.Settings do
  @moduledoc """
  Colony settings: for now, its name. Only the Dam Developer.
  """
  use BeaverColonyWeb, :live_view

  on_mount {BeaverColonyWeb.BeaverAuth, {:require, :manage_colony}}

  alias BeaverColony.Accounts.Scope
  alias BeaverColony.Colonies

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav}>
      <.header>
        Colony settings
      </.header>

      <.form for={@form} id="colony-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.button variant="primary" phx-disable-with="Saving...">Save</.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    colony = socket.assigns.current_scope.colony

    {:ok,
     socket
     |> assign(:page_title, "Colony settings")
     |> assign(:form, to_form(Colonies.change_colony(colony)))}
  end

  @impl true
  def handle_event("validate", %{"colony" => params}, socket) do
    changeset = Colonies.change_colony(socket.assigns.current_scope.colony, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"colony" => params}, socket) do
    scope = socket.assigns.current_scope

    case Colonies.rename_colony(scope, params) do
      {:ok, colony} ->
        {:noreply,
         socket
         # The scope holds the colony, so it has to be refreshed with the new name.
         |> assign(:current_scope, Scope.put_colony(scope, colony, scope.role))
         |> assign(:form, to_form(Colonies.change_colony(colony)))
         |> put_flash(:info, "Colony renamed.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Only the Dam Developer can rename the colony.")}
    end
  end
end
