defmodule BeaverColonyWeb.DamLiveTest do
  use BeaverColonyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeaverColony.AccountsFixtures
  import BeaverColony.ColoniesFixtures
  import BeaverColony.DamsFixtures

  alias BeaverColony.Accounts.Scope
  alias BeaverColony.Dams

  setup :register_and_log_in_beaver_with_colony

  # Another member of the same colony, to place sticks from "somewhere else".
  defp other_member(colony, role \\ :builder) do
    beaver = beaver_fixture()
    membership_fixture(beaver, colony, role)
    Scope.put_colony(Scope.for_beaver(beaver), colony, role)
  end

  @tag role: :builder
  test "a builder places a stick", %{conn: conn, colony: colony, scope: scope} do
    {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/dam")
    assert has_element?(lv, "#stick-preview")

    lv |> form("#stick-form", stick: %{length: 12, x: 30}) |> render_change()
    lv |> form("#stick-form") |> render_submit()

    assert [stick] = Dams.list_sticks(scope)
    assert {stick.x, stick.length} == {30, 12}
    assert has_element?(lv, "#stick-#{stick.id}")
  end

  @tag role: :builder
  test "sticks placed by other beavers appear live", %{conn: conn, colony: colony} do
    {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/dam")

    stick = stick_fixture(other_member(colony))

    assert has_element?(lv, "#stick-#{stick.id}")
  end

  @tag role: :builder
  test "a builder can't pull sticks out", %{conn: conn, colony: colony} do
    stick = stick_fixture(other_member(colony))
    {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/dam")

    refute has_element?(lv, "#stick-#{stick.id}[phx-click]")
  end

  @tag role: :lodge_keeper
  test "a lodge keeper pulls a stick out", %{conn: conn, colony: colony, scope: scope} do
    stick = stick_fixture(other_member(colony))
    {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/dam")

    lv |> element("#stick-#{stick.id}") |> render_click()

    refute has_element?(lv, "#stick-#{stick.id}")
    assert Dams.list_sticks(scope) == []
  end
end
