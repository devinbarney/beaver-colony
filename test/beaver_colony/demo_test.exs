defmodule BeaverColony.DemoTest do
  # Not async: some tests switch demos off through the application environment.
  use BeaverColonyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BeaverColony.{Colonies, Demo}
  alias BeaverColony.Accounts.Scope

  setup do
    :ok = Demo.seed!()
    :ok
  end

  defp with_demos_off(fun) do
    previous = Application.get_env(:beaver_colony, :demo)
    Application.put_env(:beaver_colony, :demo, enabled: false)

    try do
      fun.()
    after
      Application.put_env(:beaver_colony, :demo, previous)
    end
  end

  defp colony_names(beaver) do
    beaver |> Scope.for_beaver() |> Colonies.list_memberships() |> Enum.map(& &1.colony.name)
  end

  describe "seed!/0" do
    test "can run again without duplicating anything" do
      {beaver, _} = Demo.sign_in_as(:lodge_keeper)
      before = colony_names(beaver)

      :ok = Demo.seed!()
      assert colony_names(beaver) == before
      assert before == ["Klamath Colony", "Willamette Colony"]
    end
  end

  describe "sign_in_as/1" do
    test "gives each role's beaver, landing in Willamette Colony" do
      for role <- Demo.roles() do
        assert {beaver, "/colonies/" <> colony_id} = Demo.sign_in_as(role)
        scope = Scope.for_beaver(beaver)
        assert {:ok, %{role: ^role}} = Colonies.fetch_membership(scope, colony_id)
      end
    end

    test "is nil when demos are off" do
      with_demos_off(fn -> assert Demo.sign_in_as(:builder) == nil end)
    end
  end

  describe "reset!/0" do
    test "puts the demo colonies back as they started" do
      {dam, landing} = Demo.sign_in_as(:dam_developer)
      "/colonies/" <> colony_id = landing
      {:ok, membership} = Colonies.fetch_membership(Scope.for_beaver(dam), colony_id)
      scope = Scope.put_colony(Scope.for_beaver(dam), membership.colony, :dam_developer)
      {:ok, _} = Colonies.rename_colony(scope, %{name: "Renamed by a visitor"})
      {:ok, _} = Colonies.create_colony(Scope.for_beaver(dam), %{name: "A visitor's colony"})

      {:ok, :ok} = Demo.reset!()

      assert colony_names(dam) == ["Willamette Colony"]
    end
  end

  describe "POST /demo/:role" do
    test "signs in as the demo beaver and lands in their colony", %{conn: conn} do
      conn = post(conn, ~p"/demo/lodge_keeper")
      assert "/colonies/" <> _ = landing = redirected_to(conn)

      {:ok, lv, _html} = live(recycle(conn), landing)
      assert has_element?(lv, "#nav-switcher", "Lodge Keeper")
      assert has_element?(lv, "#nav-members")
    end

    test "an unknown role is a 404", %{conn: conn} do
      assert conn |> post(~p"/demo/king") |> html_response(404)
    end

    test "is a 404 when demos are off", %{conn: conn} do
      with_demos_off(fn ->
        conn = post(conn, ~p"/demo/builder")
        assert html_response(conn, 404)
        refute get_session(conn, :beaver_token)
      end)
    end
  end

  test "the reset process only starts where an interval is configured" do
    assert Demo.Reset.child_spec_if_configured() == nil
  end
end
