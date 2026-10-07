defmodule BeaverColonyWeb.NavTest do
  use BeaverColonyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeaverColony.AccountsFixtures
  import BeaverColony.ColoniesFixtures

  alias BeaverColony.Colonies
  alias BeaverColony.Colonies.Policy
  alias BeaverColonyWeb.Nav

  defp nav_for(scope, current_path \\ "") do
    Nav.build(scope, %{
      memberships: Colonies.list_memberships(scope),
      pending: 0,
      current_path: current_path
    })
  end

  defp item_ids(nav), do: Enum.map(nav.items, & &1.id)

  describe "build/2" do
    test "personal pages when there's no colony in the scope" do
      nav = nav_for(beaver_scope_fixture())

      assert item_ids(nav) == ["my_colonies", "account"]
      assert [%{label: "🦫 Me"}] = nav.context
    end

    test "each role sees only the colony pages it can open" do
      assert item_ids(nav_for(colony_scope_fixture(:builder))) == ["dashboard"]
      assert item_ids(nav_for(colony_scope_fixture(:lodge_keeper))) == ["dashboard", "members"]

      assert item_ids(nav_for(colony_scope_fixture(:dam_developer))) ==
               ["dashboard", "members", "settings"]
    end

    test "the switcher lists me and every colony with my role, marking where I am" do
      scope = colony_scope_fixture(:lodge_keeper)
      other = colony_fixture(BeaverColony.Accounts.Scope.for_beaver(scope.beaver))

      [switcher] = nav_for(scope).context
      assert switcher.label == scope.colony.name
      assert switcher.sublabel == "Lodge Keeper"

      current = for c <- switcher.children, c[:current], do: c.id
      assert current == ["colony-#{scope.colony.id}"]

      options = for c <- switcher.children, c[:sublabel], do: {c.label, c.sublabel}
      assert {scope.colony.name, "Lodge Keeper"} in options
      assert {other.name, "Dam Developer"} in options
    end

    test "marks the current page" do
      scope = colony_scope_fixture(:lodge_keeper)
      nav = nav_for(scope, ~p"/colonies/#{scope.colony}/members")

      assert [%{id: "members"}] = Enum.filter(nav.items, & &1.current)
    end

    test "the members link carries the pending count" do
      scope = colony_scope_fixture(:lodge_keeper)
      nav = Nav.build(scope, %{memberships: [], pending: 3, current_path: ""})

      assert %{badge: 3} = Enum.find(nav.items, &(&1.id == "members"))
    end
  end

  # The nav and the pages' guards both ask `Scope.can?/2`, but a page declares its own
  # ability in its LiveView. This checks they agree: for every role, a page is in the
  # nav exactly when the role can open it.
  describe "the nav and the page guards agree" do
    for role <- Policy.roles() do
      @tag role: role
      test "for a #{role}", %{conn: conn, scope: scope} do
        in_nav = item_ids(nav_for(scope))

        for page <- Nav.colony_pages(scope.colony) do
          case live(conn, page.path) do
            {:ok, _lv, _html} ->
              assert page.id in in_nav, "#{page.id} opens but isn't in the nav"

            {:error, {:redirect, _}} ->
              refute page.id in in_nav, "#{page.id} is in the nav but doesn't open"
          end
        end
      end
    end

    setup :register_and_log_in_beaver_with_colony
  end

  describe "the sidebar on a page" do
    setup :register_and_log_in_beaver_with_colony

    @tag role: :builder
    test "shows the role's pages and the switcher", %{conn: conn, colony: colony} do
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}")

      assert has_element?(lv, "#nav-dashboard a[aria-current=page]")
      refute has_element?(lv, "#nav-members")
      assert has_element?(lv, "#nav-switcher", colony.name)
      assert has_element?(lv, ".nav-toggle, label[for=nav-toggle]")
    end

    @tag role: :lodge_keeper
    test "the pending badge follows requests on the Members page", %{
      conn: conn,
      colony: colony
    } do
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/members")
      refute has_element?(lv, "#nav-members .nav-item__badge")

      {:ok, _request} = Colonies.request_to_join(beaver_scope_fixture(), colony.id)
      assert has_element?(lv, "#nav-members .nav-item__badge", "1")

      lv |> element("#pending-requests button", "Let in") |> render_click()
      refute has_element?(lv, "#nav-members .nav-item__badge")
    end

    @tag role: :builder
    test "a promotion adds pages to the open sidebar", %{
      conn: conn,
      colony: colony,
      beaver: beaver
    } do
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}")
      refute has_element?(lv, "#nav-members")

      {:ok, _} =
        Colonies.change_role(
          dam_developer_scope_fixture(colony),
          membership_id(beaver, colony),
          :lodge_keeper
        )

      assert has_element?(lv, "#nav-members")
      assert has_element?(lv, "#nav-switcher", "Lodge Keeper")
    end
  end

  describe "the sidebar on a personal page" do
    setup :register_and_log_in_beaver

    test "a colony appears in the switcher once you're let in", %{conn: conn, scope: scope} do
      keeper = colony_scope_fixture(:lodge_keeper)
      {:ok, lv, _html} = live(conn, ~p"/me/colonies")
      refute has_element?(lv, "#nav-switcher a", keeper.colony.name)

      {:ok, request} = Colonies.request_to_join(scope, keeper.colony.id)
      {:ok, _} = Colonies.approve_membership(keeper, request.id)

      assert has_element?(lv, "#nav-switcher a", keeper.colony.name)
      assert has_element?(lv, "#nav-switcher a", "Builder")
    end
  end
end
