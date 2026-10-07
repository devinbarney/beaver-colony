defmodule BeaverColonyWeb.ColonyLive.Dashboard do
  @moduledoc """
  A colony's home page. Any member may open it.
  """
  use BeaverColonyWeb, :live_view

  on_mount {BeaverColonyWeb.BeaverAuth, {:require, :view_colony}}

  alias BeaverColony.Colonies.Policy

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@current_scope.colony.name}
        <:subtitle>You're a {Policy.display_name(@current_scope.role)} here.</:subtitle>
      </.header>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, socket.assigns.current_scope.colony.name)}
  end
end
