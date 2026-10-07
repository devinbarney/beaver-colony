defmodule BeaverColonyWeb.MembershipLiveTest do
  use BeaverColonyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeaverColony.AccountsFixtures
  import BeaverColony.ColoniesFixtures

  alias BeaverColony.Colonies

  describe "joining a colony" do
    setup :register_and_log_in_beaver

    test "asking to join, then being let in while the page is open", %{conn: conn, scope: scope} do
      keeper = colony_scope_fixture(:lodge_keeper)
      {:ok, lv, html} = live(conn, ~p"/me/colonies")
      assert html =~ keeper.colony.name

      html = lv |> element("#joinable button", "Ask to join") |> render_click()
      assert html =~ "Waiting for a Lodge Keeper"

      [request] = Colonies.list_pending(keeper)
      assert request.beaver_id == scope.beaver.id
      {:ok, _} = Colonies.approve_membership(keeper, request.id)

      # No reload: the page heard about it and now lists the colony as theirs.
      assert render(lv) =~ ~p"/colonies/#{keeper.colony}"
      refute has_element?(lv, "#other-colonies")
    end
  end

  describe "the Members page" do
    setup :register_and_log_in_beaver_with_colony

    @tag role: :lodge_keeper
    test "a request shows up live, and the lodge keeper lets them in", %{
      conn: conn,
      colony: colony
    } do
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/members")
      joiner = beaver_fixture()
      {:ok, _} = Colonies.request_to_join(beaver_scope_fixture(joiner), colony.id)

      assert render(lv) =~ joiner.email

      lv |> element("#pending-requests button", "Let in") |> render_click()
      refute has_element?(lv, "#pending-requests")
      assert lv |> element("#members") |> render() =~ joiner.email
    end

    test "the dam developer promotes a builder", %{conn: conn, colony: colony} do
      membership = membership_fixture(beaver_fixture(), colony, :builder)
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/members")

      lv
      |> form("#role-#{membership.id}", %{membership_id: membership.id, role: "lodge_keeper"})
      |> render_change()

      assert render(lv) =~ "Role changed."

      assert [_, %{role: :lodge_keeper}] =
               Colonies.list_members(dam_developer_scope_fixture(colony))
    end

    @tag role: :lodge_keeper
    test "a lodge keeper can remove a builder but not change roles", %{
      conn: conn,
      colony: colony
    } do
      builder = beaver_fixture()
      membership = membership_fixture(builder, colony, :builder)
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/members")

      refute has_element?(lv, "#role-#{membership.id}")
      lv |> element("#members button", "Remove") |> render_click()
      refute lv |> element("#members") |> render() =~ builder.email
    end
  end

  describe "a change to your own membership reaches the page you have open" do
    setup :register_and_log_in_beaver_with_colony

    @tag role: :builder
    test "promoted: the page shows the new role", %{conn: conn, colony: colony, beaver: beaver} do
      {:ok, lv, html} = live(conn, ~p"/colonies/#{colony}")
      assert html =~ "a Builder here"

      {:ok, _} =
        Colonies.change_role(
          dam_developer_scope_fixture(colony),
          membership_id(beaver, colony),
          :lodge_keeper
        )

      assert render(lv) =~ "a Lodge Keeper here"
    end

    @tag role: :lodge_keeper
    test "demoted: the page the old role needed is left", %{
      conn: conn,
      colony: colony,
      beaver: beaver
    } do
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/members")

      {:ok, _} =
        Colonies.change_role(
          dam_developer_scope_fixture(colony),
          membership_id(beaver, colony),
          :builder
        )

      assert_redirect(lv, ~p"/colonies/#{colony}")
    end

    @tag role: :builder
    test "removed: the colony is left", %{conn: conn, colony: colony, beaver: beaver} do
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}")

      {:ok, _} =
        Colonies.remove_member(dam_developer_scope_fixture(colony), membership_id(beaver, colony))

      assert_redirect(lv, ~p"/me/colonies")
    end

    @tag role: :builder
    test "a change in another colony leaves this page alone", %{
      conn: conn,
      colony: colony,
      beaver: beaver
    } do
      other = colony_fixture()
      membership = membership_fixture(beaver, other, :builder)
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}")

      {:ok, _} =
        Colonies.change_role(dam_developer_scope_fixture(other), membership.id, :lodge_keeper)

      assert render(lv) =~ "a Builder here"
    end
  end
end
