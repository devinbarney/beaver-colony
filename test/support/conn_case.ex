defmodule BeaverColonyWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BeaverColonyWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint BeaverColonyWeb.Endpoint

      use BeaverColonyWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import BeaverColonyWeb.ConnCase
    end
  end

  setup tags do
    BeaverColony.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in beavers.

      setup :register_and_log_in_beaver

  It stores an updated connection and a registered beaver in the
  test context.
  """
  def register_and_log_in_beaver(%{conn: conn} = context) do
    beaver = BeaverColony.AccountsFixtures.beaver_fixture()
    scope = BeaverColony.Accounts.Scope.for_beaver(beaver)

    opts =
      context
      |> Map.take([:token_authenticated_at])
      |> Enum.into([])

    %{conn: log_in_beaver(conn, beaver, opts), beaver: beaver, scope: scope}
  end

  @doc """
  Setup helper that registers and logs in a beaver who belongs to a new colony.

  The role defaults to `:dam_developer`. Tag a test or describe block with
  `@tag role: :builder` to log in as a different role.

      setup :register_and_log_in_beaver_with_colony

  It stores an updated connection, the beaver, their colony scope and the colony in
  the test context.
  """
  def register_and_log_in_beaver_with_colony(%{conn: conn} = context) do
    scope = BeaverColony.ColoniesFixtures.colony_scope_fixture(context[:role] || :dam_developer)

    %{
      conn: log_in_beaver(conn, scope.beaver),
      beaver: scope.beaver,
      scope: scope,
      colony: scope.colony
    }
  end

  @doc """
  Logs the given `beaver` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_beaver(conn, beaver, opts \\ []) do
    token = BeaverColony.Accounts.generate_beaver_session_token(beaver)

    maybe_set_token_authenticated_at(token, opts[:token_authenticated_at])

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:beaver_token, token)
  end

  defp maybe_set_token_authenticated_at(_token, nil), do: nil

  defp maybe_set_token_authenticated_at(token, authenticated_at) do
    BeaverColony.AccountsFixtures.override_token_authenticated_at(token, authenticated_at)
  end
end
