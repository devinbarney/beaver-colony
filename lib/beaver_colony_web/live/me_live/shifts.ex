defmodule BeaverColonyWeb.MeLive.Shifts do
  @moduledoc """
  A personal page: the beaver's upcoming shifts in every colony they belong to.

  There's no colony in the scope here, and the page doesn't need one. It asks
  `BeaverColony.Building.list_my_shifts/1`, which reads only `scope.beaver`.
  """
  use BeaverColonyWeb, :live_view

  alias BeaverColony.Building
  alias BeaverColony.Building.Shift

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav}>
      <.header>
        My shifts
        <:subtitle>Everywhere you've signed up to build, in every colony.</:subtitle>
      </.header>

      <p :if={@shifts == []} id="no-shifts">
        Nothing yet. Sign up on a colony's build schedule.
      </p>

      <.table :if={@shifts != []} id="my-shifts" rows={@shifts}>
        <:col :let={shift} label="When">
          {Calendar.strftime(shift.starts_at, "%a %b %-d, %-I:%M %p")}–{Calendar.strftime(
            Shift.ends_at(shift),
            "%-I:%M %p"
          )}
        </:col>
        <:col :let={shift} label="Where">{shift.site.name}</:col>
        <:col :let={shift} label="Colony">
          <.link navigate={~p"/colonies/#{shift.colony}/schedule"} class="link">
            {shift.colony.name}
          </.link>
        </:col>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "My shifts",
       shifts: Building.list_my_shifts(socket.assigns.current_scope)
     )}
  end
end
