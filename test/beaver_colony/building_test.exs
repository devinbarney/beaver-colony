defmodule BeaverColony.BuildingTest do
  use BeaverColony.DataCase

  alias BeaverColony.Building

  describe "sites" do
    alias BeaverColony.Building.Site

    import BeaverColony.ColoniesFixtures, only: [colony_scope_fixture: 0]
    import BeaverColony.BuildingFixtures

    @invalid_attrs %{name: nil, river_mile: nil, notes: nil}

    test "list_sites/1 returns all scoped sites" do
      scope = colony_scope_fixture()
      other_scope = colony_scope_fixture()
      site = site_fixture(scope)
      other_site = site_fixture(other_scope)
      assert Building.list_sites(scope) == [site]
      assert Building.list_sites(other_scope) == [other_site]
    end

    test "get_site!/2 returns the site with given id" do
      scope = colony_scope_fixture()
      site = site_fixture(scope)
      other_scope = colony_scope_fixture()
      assert Building.get_site!(scope, site.id) == site
      assert_raise Ecto.NoResultsError, fn -> Building.get_site!(other_scope, site.id) end
    end

    test "create_site/2 with valid data creates a site" do
      valid_attrs = %{name: "some name", river_mile: 120.5, notes: "some notes"}
      scope = colony_scope_fixture()

      assert {:ok, %Site{} = site} = Building.create_site(scope, valid_attrs)
      assert site.name == "some name"
      assert site.river_mile == 120.5
      assert site.notes == "some notes"
      assert site.colony_id == scope.colony.id
    end

    test "create_site/2 with invalid data returns error changeset" do
      scope = colony_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Building.create_site(scope, @invalid_attrs)
    end

    test "update_site/3 with valid data updates the site" do
      scope = colony_scope_fixture()
      site = site_fixture(scope)
      update_attrs = %{name: "some updated name", river_mile: 456.7, notes: "some updated notes"}

      assert {:ok, %Site{} = site} = Building.update_site(scope, site, update_attrs)
      assert site.name == "some updated name"
      assert site.river_mile == 456.7
      assert site.notes == "some updated notes"
    end

    test "update_site/3 with invalid scope raises" do
      scope = colony_scope_fixture()
      other_scope = colony_scope_fixture()
      site = site_fixture(scope)

      assert_raise MatchError, fn ->
        Building.update_site(other_scope, site, %{})
      end
    end

    test "update_site/3 with invalid data returns error changeset" do
      scope = colony_scope_fixture()
      site = site_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Building.update_site(scope, site, @invalid_attrs)
      assert site == Building.get_site!(scope, site.id)
    end

    test "delete_site/2 deletes the site" do
      scope = colony_scope_fixture()
      site = site_fixture(scope)
      assert {:ok, %Site{}} = Building.delete_site(scope, site)
      assert_raise Ecto.NoResultsError, fn -> Building.get_site!(scope, site.id) end
    end

    test "delete_site/2 with invalid scope raises" do
      scope = colony_scope_fixture()
      other_scope = colony_scope_fixture()
      site = site_fixture(scope)
      assert_raise MatchError, fn -> Building.delete_site(other_scope, site) end
    end

    test "change_site/2 returns a site changeset" do
      scope = colony_scope_fixture()
      site = site_fixture(scope)
      assert %Ecto.Changeset{} = Building.change_site(scope, site)
    end
  end
end
