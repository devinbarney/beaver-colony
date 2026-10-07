defmodule BeaverColony.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        BeaverColonyWeb.Telemetry,
        BeaverColony.Repo,
        {DNSCluster, query: Application.get_env(:beaver_colony, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: BeaverColony.PubSub},
        # Resets the demo data on an interval, when configured.
        BeaverColony.Demo.Reset.child_spec_if_configured(),
        # Start to serve requests, typically the last entry
        BeaverColonyWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BeaverColony.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BeaverColonyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
