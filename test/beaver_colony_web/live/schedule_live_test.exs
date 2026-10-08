defmodule BeaverColonyWeb.ScheduleLiveTest do
  use BeaverColonyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeaverColony.AccountsFixtures
  import BeaverColony.ColoniesFixtures
  import BeaverColony.BuildingFixtures

  alias BeaverColony.Accounts.Scope
  alias BeaverColony.Building

  # Someone else in the same colony, acting with `role`.
  defp member(colony, role) do
    beaver = beaver_fixture()
    membership_fixture(beaver, colony, role)
    Scope.put_colony(Scope.for_beaver(beaver), colony, role)
  end

  describe "the build schedule" do
    setup :register_and_log_in_beaver_with_colony

    @tag role: :builder
    test "a builder signs up and withdraws, with no shift controls", %{
      conn: conn,
      colony: colony,
      beaver: beaver
    } do
      shift = shift_fixture(member(colony, :lodge_keeper))
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/schedule")

      refute has_element?(lv, "#shift-form")
      refute has_element?(lv, "#shift-#{shift.id} button", "Remove")

      lv |> element("#shift-#{shift.id} button", "Sign up") |> render_click()
      assert has_element?(lv, "#shift-#{shift.id}", "1 of 3 builders")
      assert has_element?(lv, "#shift-#{shift.id}", beaver.email)

      lv |> element("#shift-#{shift.id} button", "Withdraw") |> render_click()
      assert has_element?(lv, "#shift-#{shift.id}", "0 of 3 builders")
    end

    @tag role: :builder
    test "other beavers' sign-ups appear live", %{conn: conn, colony: colony} do
      shift = shift_fixture(member(colony, :lodge_keeper))
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/schedule")

      {:ok, _} = Building.sign_up(member(colony, :builder), shift.id)

      assert has_element?(lv, "#shift-#{shift.id}", "1 of 3 builders")
    end

    @tag role: :lodge_keeper
    test "a lodge keeper adds and removes a shift", %{conn: conn, colony: colony, scope: scope} do
      site = site_fixture(scope, %{name: "Mill Creek"})
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/schedule")
      assert has_element?(lv, "#no-shifts")

      tomorrow = Date.add(Date.utc_today(), 1)

      lv
      |> form("#shift-form",
        shift: %{site_id: site.id, starts_at: "#{tomorrow}T08:00", hours: "2", needed: "4"}
      )
      |> render_submit()

      assert [shift] = Building.list_shifts(scope)
      assert has_element?(lv, "#shift-#{shift.id}", "Mill Creek")
      assert has_element?(lv, "#shift-#{shift.id}", "0 of 4 builders")

      lv |> element("#shift-#{shift.id} button", "Remove") |> render_click()
      refute has_element?(lv, "#shift-#{shift.id}")
    end
  end

  describe "My shifts" do
    setup :register_and_log_in_beaver

    test "lists the beaver's shifts across colonies", %{conn: conn, scope: scope} do
      colonies =
        for name <- ["Willamette", "Klamath"] do
          keeper = colony_scope_fixture(:lodge_keeper)

          {:ok, colony} =
            BeaverColony.Colonies.rename_colony(dam_developer_scope_fixture(keeper.colony), %{
              name: name
            })

          membership_fixture(scope.beaver, colony, :builder)
          shift = shift_fixture(keeper)
          {:ok, _} = Building.sign_up(Scope.put_colony(scope, colony, :builder), shift.id)
          colony
        end

      {:ok, lv, _html} = live(conn, ~p"/me/shifts")

      for colony <- colonies do
        assert has_element?(lv, "#my-shifts a", colony.name)
      end

      assert has_element?(lv, "#nav-my_shifts a[aria-current=page]")
    end
  end
end
