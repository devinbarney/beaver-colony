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

  describe "shifts" do
    alias BeaverColony.Accounts.Scope
    alias BeaverColony.Building.{Shift, Signup}

    import BeaverColony.AccountsFixtures, only: [beaver_fixture: 0]

    import BeaverColony.ColoniesFixtures,
      only: [colony_scope_fixture: 0, colony_scope_fixture: 1, membership_fixture: 3]

    import BeaverColony.BuildingFixtures

    # A builder in the same colony as `scope`.
    defp builder_in(scope) do
      beaver = beaver_fixture()
      membership_fixture(beaver, scope.colony, :builder)
      Scope.put_colony(Scope.for_beaver(beaver), scope.colony, :builder)
    end

    test "list_shifts/1 returns the colony's upcoming shifts only" do
      scope = colony_scope_fixture()
      shift = shift_fixture(scope)
      _other = shift_fixture(colony_scope_fixture())

      _past =
        shift_fixture(scope, %{starts_at: NaiveDateTime.add(NaiveDateTime.utc_now(), -1, :day)})

      assert [%Shift{id: id}] = Building.list_shifts(scope)
      assert id == shift.id
    end

    test "get_shift!/2 won't find another colony's shift" do
      shift = shift_fixture(colony_scope_fixture())

      assert_raise Ecto.NoResultsError, fn ->
        Building.get_shift!(colony_scope_fixture(), shift.id)
      end
    end

    test "create_shift/2 needs a site in the scope's own colony" do
      scope = colony_scope_fixture()
      other_site = site_fixture(colony_scope_fixture())

      assert Building.create_shift(scope, %{
               site_id: other_site.id,
               hours: 2,
               needed: 2,
               starts_at: ~N[2030-01-01 09:00:00]
             }) == {:error, :not_found}

      assert Building.create_shift(scope, %{
               site_id: "nope",
               hours: 2,
               needed: 2,
               starts_at: ~N[2030-01-01 09:00:00]
             }) == {:error, :not_found}
    end

    test "create_shift/2 validates hours and builders needed" do
      scope = colony_scope_fixture()
      site = site_fixture(scope)

      assert {:error, changeset} =
               Building.create_shift(scope, %{
                 site_id: site.id,
                 hours: 12,
                 needed: 0,
                 starts_at: ~N[2030-01-01 09:00:00]
               })

      assert errors_on(changeset) |> Map.keys() |> Enum.sort() == [:hours, :needed]
    end

    test "create_shift/2 and delete_shift/2 need a lodge keeper" do
      keeper = colony_scope_fixture(:lodge_keeper)
      shift = shift_fixture(keeper)
      builder = builder_in(keeper)

      assert Building.create_shift(builder, %{site_id: shift.site_id}) == {:error, :unauthorized}
      assert Building.delete_shift(builder, shift) == {:error, :unauthorized}
      assert {:ok, _} = Building.delete_shift(keeper, shift)
    end

    test "a builder signs up, and can't twice" do
      scope = colony_scope_fixture()
      shift = shift_fixture(scope)
      builder = builder_in(scope)

      assert {:ok, %Signup{}} = Building.sign_up(builder, shift.id)
      assert {:error, %Ecto.Changeset{}} = Building.sign_up(builder, shift.id)
    end

    test "a full shift takes no one else" do
      scope = colony_scope_fixture()
      shift = shift_fixture(scope, %{needed: 1})

      assert {:ok, _} = Building.sign_up(builder_in(scope), shift.id)
      assert Building.sign_up(builder_in(scope), shift.id) == {:error, :full}
    end

    test "can't sign up for another colony's shift" do
      shift = shift_fixture(colony_scope_fixture())
      assert Building.sign_up(colony_scope_fixture(:builder), shift.id) == {:error, :not_found}
    end

    test "withdraw/2 takes you off, and only you" do
      scope = colony_scope_fixture()
      shift = shift_fixture(scope)
      builder = builder_in(scope)
      {:ok, _} = Building.sign_up(builder, shift.id)

      assert Building.withdraw(builder_in(scope), shift.id) == {:error, :not_found}
      assert {:ok, _} = Building.withdraw(builder, shift.id)
      assert [%{signups: []}] = Building.list_shifts(scope)
    end

    test "list_my_shifts/1 spans every colony the beaver is in, and only those" do
      beaver = beaver_fixture()
      [a, b] = for _ <- 1..2, do: colony_scope_fixture()

      [mine_a, mine_b] =
        for scope <- [a, b] do
          membership_fixture(beaver, scope.colony, :builder)
          shift = shift_fixture(scope)

          {:ok, _} =
            Building.sign_up(
              Scope.put_colony(Scope.for_beaver(beaver), scope.colony, :builder),
              shift.id
            )

          shift
        end

      _not_mine = shift_fixture(a)
      personal = Scope.for_beaver(beaver)

      assert personal |> Building.list_my_shifts() |> Enum.map(& &1.id) |> Enum.sort() ==
               Enum.sort([mine_a.id, mine_b.id])

      # Removed from colony b: its shifts drop off the personal page.
      {:ok, _} =
        BeaverColony.Colonies.remove_member(
          BeaverColony.ColoniesFixtures.dam_developer_scope_fixture(b.colony),
          BeaverColony.ColoniesFixtures.membership_id(beaver, b.colony)
        )

      assert personal |> Building.list_my_shifts() |> Enum.map(& &1.id) == [mine_a.id]
    end
  end
end
