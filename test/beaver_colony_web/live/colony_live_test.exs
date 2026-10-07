defmodule BeaverColonyWeb.ColonyLiveTest do
  use BeaverColonyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BeaverColony.ColoniesFixtures

  describe "My colonies" do
    setup :register_and_log_in_beaver

    test "lists the beaver's colonies", %{conn: conn, scope: scope} do
      colony = colony_fixture(scope, %{name: "Willamette"})

      {:ok, _lv, html} = live(conn, ~p"/me/colonies")

      assert html =~ "Willamette"
      assert html =~ ~p"/colonies/#{colony}"
      assert html =~ "Dam Developer"
    end

    test "founds a colony and goes to it", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/me/colonies")

      assert {:ok, _lv, html} =
               lv
               |> form("#colony-form", colony: %{name: "Klamath"})
               |> render_submit()
               |> follow_redirect(conn)

      assert html =~ "Klamath"
      assert html =~ "You&#39;re a Dam Developer here."
    end

    test "requires a signed-in beaver" do
      conn = build_conn()
      assert {:error, {:redirect, %{to: "/beavers/log-in"}}} = live(conn, ~p"/me/colonies")
    end
  end

  describe "entering a colony" do
    setup :register_and_log_in_beaver_with_colony

    test "a member sees the colony with their role", %{conn: conn, colony: colony} do
      {:ok, _lv, html} = live(conn, ~p"/colonies/#{colony}")

      assert html =~ colony.name
      assert html =~ "Dam Developer"
    end

    test "another colony's pages redirect, as if the colony didn't exist", %{conn: conn} do
      other = colony_scope_fixture().colony

      for path <- [~p"/colonies/#{other}", ~p"/colonies/#{other}/members"] do
        assert {:error, {:redirect, %{to: "/me/colonies", flash: flash}}} = live(conn, path)
        assert flash["error"] == "You aren't a member of that colony."
      end

      assert {:error, {:redirect, %{to: "/me/colonies"}}} =
               live(conn, ~p"/colonies/#{Ecto.UUID.generate()}")
    end

    test "a pending member can't get in", %{conn: conn, beaver: beaver} do
      colony = colony_fixture()
      membership_fixture(beaver, colony, :builder, :pending)

      assert {:error, {:redirect, %{to: "/me/colonies"}}} = live(conn, ~p"/colonies/#{colony}")
    end

    test "patching to another colony's URL is refused", %{
      conn: conn,
      beaver: beaver,
      colony: colony
    } do
      other = colony_scope_fixture().colony
      membership_fixture(beaver, other, :dam_developer)

      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/members")

      # Even a colony the beaver *is* in: the mounted page's scope belongs to `colony`.
      assert {:error, {:redirect, %{to: "/me/colonies"}}} =
               render_patch(lv, ~p"/colonies/#{other}/members")
    end
  end

  describe "each page declares the ability it needs" do
    setup :register_and_log_in_beaver_with_colony

    @tag role: :builder
    test "a builder sees the dashboard but not members or settings", %{
      conn: conn,
      colony: colony
    } do
      assert {:ok, _lv, _html} = live(conn, ~p"/colonies/#{colony}")

      for path <- [~p"/colonies/#{colony}/members", ~p"/colonies/#{colony}/settings"] do
        assert {:error, {:redirect, %{to: to, flash: flash}}} = live(conn, path)
        assert to == ~p"/colonies/#{colony}"
        assert flash["error"] == "Your role in this colony can't open that page."
      end
    end

    @tag role: :lodge_keeper
    test "a lodge keeper sees members but not settings", %{conn: conn, colony: colony} do
      {:ok, _lv, html} = live(conn, ~p"/colonies/#{colony}/members")
      assert html =~ "Lodge Keeper"

      assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/colonies/#{colony}/settings")
      assert to == ~p"/colonies/#{colony}"
    end

    test "a dam developer renames the colony", %{conn: conn, colony: colony} do
      {:ok, lv, _html} = live(conn, ~p"/colonies/#{colony}/settings")

      html =
        lv
        |> form("#colony-form", colony: %{name: "Upper Willamette"})
        |> render_submit()

      assert html =~ "Colony renamed."
      assert {:ok, _lv, html} = live(conn, ~p"/colonies/#{colony}")
      assert html =~ "Upper Willamette"
    end
  end
end
