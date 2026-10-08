defmodule BeaverColonyWeb.ColonyLive.Schedule do
  @moduledoc """
  The colony's build schedule: upcoming shifts at its sites, by day. Builders sign up
  or withdraw; Lodge Keepers and up add and remove shifts. Updates live.
  """
  use BeaverColonyWeb, :live_view

  on_mount {BeaverColonyWeb.BeaverAuth, {:require, :view_schedule}}

  alias BeaverColony.Accounts.Scope
  alias BeaverColony.Building
  alias BeaverColony.Building.Shift

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={@nav}>
      <.header>
        Build schedule
        <:subtitle>Who's building where, and when, in {@current_scope.colony.name}.</:subtitle>
      </.header>

      <p :if={@days == []} id="no-shifts">No shifts coming up.</p>

      <section :for={{day, shifts} <- @days} class="space-y-2 pt-4">
        <h2 class="font-semibold">{Calendar.strftime(day, "%A, %B %-d")}</h2>

        <div
          :for={shift <- shifts}
          id={"shift-#{shift.id}"}
          class="rounded-box border border-base-300 p-4 flex flex-wrap items-center gap-4"
        >
          <div class="flex-1 min-w-48">
            <p class="font-medium">
              {Calendar.strftime(shift.starts_at, "%-I:%M %p")}–{Calendar.strftime(
                Shift.ends_at(shift),
                "%-I:%M %p"
              )} at {shift.site.name}
            </p>
            <p class="text-sm opacity-70">
              {length(shift.signups)} of {shift.needed} builders
              <span :if={shift.signups != []}>
                · {Enum.map_join(shift.signups, ", ", & &1.beaver.email)}
              </span>
            </p>
          </div>

          <.button
            :if={signed_up?(shift, @current_scope) and @can_sign_up}
            phx-click="withdraw"
            phx-value-id={shift.id}
          >
            Withdraw
          </.button>
          <.button
            :if={!signed_up?(shift, @current_scope) and @can_sign_up and !full?(shift)}
            variant="primary"
            phx-click="sign_up"
            phx-value-id={shift.id}
          >
            Sign up
          </.button>
          <span :if={!signed_up?(shift, @current_scope) and full?(shift)} class="badge">Full</span>
          <.button
            :if={@can_manage}
            phx-click="delete"
            phx-value-id={shift.id}
            data-confirm="Remove this shift and its sign-ups?"
          >
            Remove
          </.button>
        </div>
      </section>

      <section :if={@can_manage} class="space-y-2 pt-6">
        <h2 class="font-semibold">Add a shift</h2>
        <p :if={@sites == []}>
          Add a
          <.link navigate={~p"/colonies/#{@current_scope.colony}/sites"} class="link">build site</.link>
          first.
        </p>
        <.form
          :if={@sites != []}
          for={@form}
          id="shift-form"
          phx-change="validate"
          phx-submit="save"
        >
          <.input
            field={@form[:site_id]}
            type="select"
            label="Site"
            options={Enum.map(@sites, &{&1.name, &1.id})}
          />
          <.input field={@form[:starts_at]} type="datetime-local" label="Starts" />
          <.input field={@form[:hours]} type="number" label="Hours" min="1" max="8" />
          <.input field={@form[:needed]} type="number" label="Builders needed" min="1" max="10" />
          <.button variant="primary" phx-disable-with="Adding...">Add shift</.button>
        </.form>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    if connected?(socket), do: Building.subscribe_schedule(scope)

    {:ok,
     socket
     |> assign(:page_title, "Build schedule")
     |> assign(:can_sign_up, Scope.can?(scope, :sign_up))
     |> assign(:can_manage, Scope.can?(scope, :manage_schedule))
     |> assign(:sites, Building.list_sites(scope))
     |> assign_form(default_params(scope))
     |> load_shifts()}
  end

  @impl true
  def handle_event("validate", %{"shift" => params}, socket) do
    {:noreply, assign_form(socket, params, :validate)}
  end

  def handle_event("save", %{"shift" => params}, socket) do
    scope = socket.assigns.current_scope

    case Building.create_shift(scope, params) do
      {:ok, _shift} ->
        {:noreply,
         socket |> put_flash(:info, "Shift added.") |> assign_form(default_params(scope))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :shift))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Pick one of this colony's build sites.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "Your role can't add shifts.")}
    end
  end

  def handle_event("sign_up", %{"id" => id}, socket) do
    case Building.sign_up(socket.assigns.current_scope, id) do
      {:ok, _} -> {:noreply, load_shifts(socket)}
      {:error, :full} -> {:noreply, flash_and_load(socket, "That shift just filled up.")}
      {:error, :started} -> {:noreply, flash_and_load(socket, "That shift has already started.")}
      {:error, _} -> {:noreply, flash_and_load(socket, "Couldn't sign you up.")}
    end
  end

  def handle_event("withdraw", %{"id" => id}, socket) do
    case Building.withdraw(socket.assigns.current_scope, id) do
      {:ok, _} -> {:noreply, load_shifts(socket)}
      {:error, _} -> {:noreply, flash_and_load(socket, "You weren't on that shift.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Building.delete_shift(scope, Building.get_shift!(scope, id)) do
      {:ok, _} -> {:noreply, load_shifts(socket)}
      {:error, :unauthorized} -> {:noreply, put_flash(socket, :error, "Your role can't do that.")}
    end
  end

  # Someone added or removed a shift, or signed up or withdrew.
  @impl true
  def handle_info({:schedule_changed, _colony_id}, socket) do
    {:noreply, load_shifts(socket)}
  end

  defp load_shifts(socket) do
    days =
      socket.assigns.current_scope
      |> Building.list_shifts()
      |> Enum.chunk_by(&NaiveDateTime.to_date(&1.starts_at))
      |> Enum.map(fn [first | _] = shifts -> {NaiveDateTime.to_date(first.starts_at), shifts} end)

    assign(socket, :days, days)
  end

  defp flash_and_load(socket, message), do: socket |> put_flash(:error, message) |> load_shifts()

  defp assign_form(socket, params, action \\ nil) do
    scope = socket.assigns.current_scope
    changeset = Building.change_shift(scope, %Shift{colony_id: scope.colony.id}, params)
    assign(socket, :form, to_form(changeset, as: :shift, action: action))
  end

  # Tomorrow at nine, three hours, three builders, at the first site.
  defp default_params(scope) do
    tomorrow = Date.add(Date.utc_today(), 1)

    %{
      "site_id" => scope |> Building.list_sites() |> List.first() |> then(&(&1 && &1.id)),
      "starts_at" => "#{tomorrow}T09:00",
      "hours" => "3",
      "needed" => "3"
    }
  end

  defp signed_up?(shift, scope), do: Enum.any?(shift.signups, &(&1.beaver_id == scope.beaver.id))
  defp full?(shift), do: length(shift.signups) >= shift.needed
end
