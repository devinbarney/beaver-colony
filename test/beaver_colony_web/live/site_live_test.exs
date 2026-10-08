defmodule BeaverColonyWeb.SiteLiveTest do
  use BeaverColonyWeb.ConnCase

  import Phoenix.LiveViewTest
  import BeaverColony.BuildingFixtures

  @create_attrs %{name: "some name", river_mile: 120.5, notes: "some notes"}
  @update_attrs %{name: "some updated name", river_mile: 456.7, notes: "some updated notes"}
  @invalid_attrs %{name: nil, river_mile: nil, notes: nil}

  setup :register_and_log_in_beaver_with_colony

  defp create_site(%{scope: scope}) do
    site = site_fixture(scope)

    %{site: site}
  end

  describe "Index" do
    setup [:create_site]

    test "lists all sites", %{conn: conn, site: site, scope: scope} do
      {:ok, _index_live, html} = live(conn, ~p"/colonies/#{scope.colony.id}/sites")

      assert html =~ "Build sites"
      assert html =~ site.name
    end

    test "saves new site", %{conn: conn, scope: scope} do
      {:ok, index_live, _html} = live(conn, ~p"/colonies/#{scope.colony.id}/sites")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New build site")
               |> render_click()
               |> follow_redirect(conn, ~p"/colonies/#{scope.colony.id}/sites/new")

      assert render(form_live) =~ "New build site"

      assert form_live
             |> form("#site-form", site: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#site-form", site: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/colonies/#{scope.colony.id}/sites")

      html = render(index_live)
      assert html =~ "Build site added"
      assert html =~ "some name"
    end

    test "updates site in listing", %{conn: conn, site: site, scope: scope} do
      {:ok, index_live, _html} = live(conn, ~p"/colonies/#{scope.colony.id}/sites")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#sites-#{site.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/colonies/#{scope.colony.id}/sites/#{site}/edit")

      assert render(form_live) =~ "Edit build site"

      assert form_live
             |> form("#site-form", site: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#site-form", site: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/colonies/#{scope.colony.id}/sites")

      html = render(index_live)
      assert html =~ "Build site updated"
      assert html =~ "some updated name"
    end

    test "deletes site in listing", %{conn: conn, site: site, scope: scope} do
      {:ok, index_live, _html} = live(conn, ~p"/colonies/#{scope.colony.id}/sites")

      assert index_live |> element("#sites-#{site.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#sites-#{site.id}")
    end
  end

  describe "Show" do
    setup [:create_site]

    test "displays site", %{conn: conn, site: site, scope: scope} do
      {:ok, _show_live, html} = live(conn, ~p"/colonies/#{scope.colony.id}/sites/#{site}")

      assert html =~ "Build site"
      assert html =~ site.name
    end

    test "updates site and returns to show", %{conn: conn, site: site, scope: scope} do
      {:ok, show_live, _html} = live(conn, ~p"/colonies/#{scope.colony.id}/sites/#{site}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/colonies/#{scope.colony.id}/sites/#{site}/edit?return_to=show"
               )

      assert render(form_live) =~ "Edit build site"

      assert form_live
             |> form("#site-form", site: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#site-form", site: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/colonies/#{scope.colony.id}/sites/#{site}")

      html = render(show_live)
      assert html =~ "Build site updated"
      assert html =~ "some updated name"
    end
  end

  describe "for a builder" do
    setup :register_and_log_in_beaver_with_colony

    @tag role: :builder
    test "sites are listed, but with nothing to change them", %{conn: conn, scope: scope} do
      site =
        site_fixture(
          BeaverColony.Accounts.Scope.put_colony(
            BeaverColony.AccountsFixtures.beaver_scope_fixture(),
            scope.colony,
            :lodge_keeper
          )
        )

      {:ok, lv, _html} = live(conn, ~p"/colonies/#{scope.colony}/sites")

      assert has_element?(lv, "#sites", site.name)
      refute has_element?(lv, "a", "New build site")
      refute has_element?(lv, "#sites a", "Edit")
      refute has_element?(lv, "#sites a", "Delete")
    end

    @tag role: :builder
    test "the form won't open", %{conn: conn, scope: scope} do
      assert {:error, {:redirect, %{to: to}}} =
               live(conn, ~p"/colonies/#{scope.colony}/sites/new")

      assert to == ~p"/colonies/#{scope.colony}"
    end

    @tag role: :builder
    test "the context refuses a builder's write", %{scope: scope} do
      assert BeaverColony.Building.create_site(scope, %{name: "Mine"}) == {:error, :unauthorized}
    end
  end
end
