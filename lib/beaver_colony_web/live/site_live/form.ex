defmodule BeaverColonyWeb.SiteLive.Form do
  use BeaverColonyWeb, :live_view

  on_mount {BeaverColonyWeb.BeaverAuth, {:require, :manage_sites}}

  alias BeaverColony.Building
  alias BeaverColony.Building.Site

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav}>
      <.header>
        {@page_title}
        <:subtitle>A place along the river where the colony can build.</:subtitle>
      </.header>

      <.form for={@form} id="site-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:river_mile]} type="number" label="River mile" step="any" />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Site</.button>
          <.button navigate={return_path(@current_scope, @return_to, @site)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    site = Building.get_site!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit build site")
    |> assign(:site, site)
    |> assign(:form, to_form(Building.change_site(socket.assigns.current_scope, site)))
  end

  defp apply_action(socket, :new, _params) do
    site = %Site{colony_id: socket.assigns.current_scope.colony.id}

    socket
    |> assign(:page_title, "New build site")
    |> assign(:site, site)
    |> assign(:form, to_form(Building.change_site(socket.assigns.current_scope, site)))
  end

  @impl true
  def handle_event("validate", %{"site" => site_params}, socket) do
    changeset =
      Building.change_site(socket.assigns.current_scope, socket.assigns.site, site_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"site" => site_params}, socket) do
    save_site(socket, socket.assigns.live_action, site_params)
  end

  defp save_site(socket, :edit, site_params) do
    case Building.update_site(socket.assigns.current_scope, socket.assigns.site, site_params) do
      {:ok, site} ->
        {:noreply,
         socket
         |> put_flash(:info, "Build site updated")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, site)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Your role can't change build sites.")}
    end
  end

  defp save_site(socket, :new, site_params) do
    case Building.create_site(socket.assigns.current_scope, site_params) do
      {:ok, site} ->
        {:noreply,
         socket
         |> put_flash(:info, "Build site added")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, site)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Your role can't change build sites.")}
    end
  end

  defp return_path(scope, "index", _site), do: ~p"/colonies/#{scope.colony.id}/sites"
  defp return_path(scope, "show", site), do: ~p"/colonies/#{scope.colony.id}/sites/#{site}"
end
