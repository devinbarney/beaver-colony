defmodule BeaverColony.Demo.Reset do
  @moduledoc """
  Resets the demo data on an interval, so a public demo doesn't collect every visitor's
  changes forever. Only started when configured:

      config :beaver_colony, :demo, enabled: true, reset_every: :timer.hours(24)
  """
  use GenServer

  require Logger

  def start_link(every), do: GenServer.start_link(__MODULE__, every, name: __MODULE__)

  @doc "The child spec to start, or `nil` when no reset interval is configured."
  def child_spec_if_configured do
    demo = Application.get_env(:beaver_colony, :demo, [])

    if demo[:enabled] == true and is_integer(demo[:reset_every]),
      do: {__MODULE__, demo[:reset_every]}
  end

  @impl true
  def init(every) do
    schedule(every)
    {:ok, every}
  end

  @impl true
  def handle_info(:reset, every) do
    {:ok, _} = BeaverColony.Demo.reset!()
    Logger.info("Demo data reset")
    schedule(every)
    {:noreply, every}
  end

  defp schedule(every), do: Process.send_after(self(), :reset, every)
end
