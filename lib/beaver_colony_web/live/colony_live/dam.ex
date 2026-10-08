defmodule BeaverColonyWeb.ColonyLive.Dam do
  @moduledoc """
  The colony's dam, drawn from its sticks, updating live as members place them.
  Builders place sticks; Lodge Keepers and up can pull one out.
  """
  use BeaverColonyWeb, :live_view

  on_mount {BeaverColonyWeb.BeaverAuth, {:require, :view_dam}}

  alias BeaverColony.Accounts.Scope
  alias BeaverColony.Dams
  alias BeaverColony.Dams.Stick

  @row_height 4
  @min_rows 8
  @colors ~w(#8b5a2b #a0522d #6f4518 #996633 #7b4a12 #b07a3f)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav}>
      <.header>
        The dam
        <:subtitle>
          {length(@sticks)} sticks so far, {@mine} of them yours. Everyone in {@current_scope.colony.name} sees each one land.
        </:subtitle>
      </.header>

      <svg
        id="dam"
        viewBox={"0 0 #{Stick.dam_width()} #{@height}"}
        class="w-full rounded-box border border-base-300"
        role="img"
        aria-label={"The dam: #{length(@sticks)} sticks"}
      >
        <rect x="0" y="0" width="100%" height="100%" fill="var(--color-info)" opacity="0.15" />
        <rect
          x="0"
          y={@height - 1}
          width="100%"
          height="1"
          fill="var(--color-base-content)"
          opacity="0.3"
        />

        <rect
          :for={{stick, row} <- @stacked}
          id={"stick-#{stick.id}"}
          x={stick.x + 0.15}
          y={y(row, @height)}
          width={stick.length - 0.3}
          height={@row_height - 0.6}
          rx="1.2"
          fill={color(stick)}
          stroke={if stick.beaver_id == @current_scope.beaver.id, do: "var(--color-base-content)"}
          stroke-width="0.35"
          phx-click={@can_remove && "remove"}
          phx-value-id={stick.id}
          class={@can_remove && "cursor-pointer"}
        >
          <title>Placed by {placed_by(stick)}</title>
        </rect>

        <rect
          :if={@preview}
          id="stick-preview"
          x={@preview.x + 0.15}
          y={y(@preview_row, @height)}
          width={@preview.length - 0.3}
          height={@row_height - 0.6}
          rx="1.2"
          fill="none"
          stroke="var(--color-primary)"
          stroke-width="0.4"
          stroke-dasharray="1 0.6"
        />
      </svg>

      <p :if={@can_remove} class="text-sm opacity-70">
        As a {BeaverColony.Colonies.Policy.display_name(@current_scope.role)} you can click a
        stick to pull it out. The ones above it settle.
      </p>

      <.form
        :if={@can_place}
        for={@form}
        id="stick-form"
        phx-change="preview"
        phx-submit="place"
        class="space-y-4"
      >
        <label class="block">
          <span class="text-sm">Length: {@preview.length}</span>
          <input
            type="range"
            name={@form[:length].name}
            value={@preview.length}
            min={Stick.lengths().first}
            max={Stick.lengths().last}
            class="range range-sm w-full"
          />
        </label>
        <label class="block">
          <span class="text-sm">Where along the dam: {@preview.x}</span>
          <input
            type="range"
            name={@form[:x].name}
            value={@preview.x}
            min="0"
            max={Stick.dam_width() - @preview.length}
            class="range range-sm w-full"
          />
        </label>
        <.button variant="primary" phx-disable-with="Placing...">Place stick</.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    if connected?(socket), do: Dams.subscribe_sticks(scope)

    preview = %{x: 40, length: 20}

    {:ok,
     socket
     |> assign(:page_title, "The dam")
     |> assign(:row_height, @row_height)
     |> assign(:can_place, Scope.can?(scope, :place_stick))
     |> assign(:can_remove, Scope.can?(scope, :remove_stick))
     |> assign(:form, to_form(%{"x" => preview.x, "length" => preview.length}, as: :stick))
     |> assign(:preview, preview)
     |> load_sticks()}
  end

  @impl true
  def handle_event("preview", %{"stick" => params}, socket) do
    length = clamp(params["length"], Stick.lengths().first, Stick.lengths().last)
    x = clamp(params["x"], 0, Stick.dam_width() - length)

    {:noreply, socket |> assign(:preview, %{x: x, length: length}) |> place_preview()}
  end

  def handle_event("place", %{"stick" => _params}, socket) do
    case Dams.create_stick(socket.assigns.current_scope, socket.assigns.preview) do
      {:ok, _stick} ->
        {:noreply, load_sticks(socket)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, error_message(changeset))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Your role can't place sticks.")}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    stick = Dams.get_stick!(scope, id)

    case Dams.delete_stick(scope, stick) do
      {:ok, _stick} -> {:noreply, load_sticks(socket)}
      {:error, :unauthorized} -> {:noreply, put_flash(socket, :error, "Your role can't do that.")}
    end
  end

  # Another beaver placed or pulled a stick. Draw the dam again.
  @impl true
  def handle_info({type, %Stick{}}, socket) when type in [:created, :deleted] do
    {:noreply, load_sticks(socket)}
  end

  defp load_sticks(socket) do
    sticks = Dams.list_sticks(socket.assigns.current_scope)
    me = socket.assigns.current_scope.beaver.id

    socket
    |> assign(:sticks, sticks)
    |> assign(:stacked, Dams.layout(sticks))
    |> assign(:mine, Enum.count(sticks, &(&1.beaver_id == me)))
    |> place_preview()
  end

  # Where the ghost stick would land if placed now, and how tall the drawing must be.
  defp place_preview(socket) do
    %{stacked: stacked, preview: preview, sticks: sticks} = socket.assigns
    top = stacked |> Enum.map(fn {_stick, row} -> row end) |> Enum.max(fn -> -1 end)

    {_ghost, preview_row} =
      if socket.assigns.can_place,
        do: List.last(Dams.layout(sticks ++ [struct(Stick, preview)])),
        else: {nil, -1}

    rows = Enum.max([@min_rows, top + 3, preview_row + 3])

    socket
    |> assign(:preview, if(socket.assigns.can_place, do: preview))
    |> assign(:preview_row, preview_row)
    |> assign(:height, rows * @row_height)
  end

  defp y(row, height), do: height - 1 - (row + 1) * @row_height + 0.3

  defp color(%Stick{beaver_id: nil}), do: "#8b7765"
  defp color(%Stick{beaver_id: id}), do: Enum.at(@colors, :erlang.phash2(id, length(@colors)))

  defp placed_by(%Stick{beaver: %{email: email}}), do: email
  defp placed_by(_stick), do: "a beaver who has left"

  defp clamp(value, low, high) do
    case Integer.parse(to_string(value)) do
      {n, _} -> n |> max(low) |> min(high)
      :error -> low
    end
  end

  defp error_message(changeset) do
    changeset.errors |> Enum.map(fn {_field, {message, _}} -> message end) |> Enum.join(", ")
  end
end
