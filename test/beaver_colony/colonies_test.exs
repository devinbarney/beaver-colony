defmodule BeaverColony.ColoniesTest do
  use BeaverColony.DataCase, async: true

  import BeaverColony.AccountsFixtures
  import BeaverColony.ColoniesFixtures

  alias BeaverColony.Colonies
  alias BeaverColony.Colonies.Colony

  describe "create_colony/2" do
    test "founds a colony with the founder as its Dam Developer" do
      scope = beaver_scope_fixture()

      assert {:ok, %Colony{name: "Willamette"} = colony} =
               Colonies.create_colony(scope, %{name: "Willamette"})

      assert {:ok, membership} = Colonies.fetch_membership(scope, colony.id)
      assert membership.role == :dam_developer
    end

    test "needs a name" do
      assert {:error, changeset} = Colonies.create_colony(beaver_scope_fixture(), %{name: ""})
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "list_memberships/1" do
    test "lists only the beaver's own approved memberships" do
      scope = beaver_scope_fixture()
      mine = colony_fixture(scope, %{name: "A colony"})
      pending = colony_fixture()
      membership_fixture(scope.beaver, pending, :builder, :pending)
      _someone_elses = colony_fixture()

      assert [membership] = Colonies.list_memberships(scope)
      assert membership.colony.id == mine.id
    end
  end

  describe "fetch_membership/2" do
    setup do
      %{scope: beaver_scope_fixture()}
    end

    test "finds the beaver's approved membership, with its colony", %{scope: scope} do
      colony = colony_fixture()
      membership_fixture(scope.beaver, colony, :lodge_keeper)

      assert {:ok, membership} = Colonies.fetch_membership(scope, colony.id)
      assert membership.colony.id == colony.id
      assert membership.role == :lodge_keeper
    end

    # These four look the same to the caller on purpose: the answer must not reveal
    # whether a colony exists.
    test "a colony the beaver isn't in is not found", %{scope: scope} do
      assert Colonies.fetch_membership(scope, colony_fixture().id) == {:error, :not_found}
    end

    test "a pending membership is not found", %{scope: scope} do
      colony = colony_fixture()
      membership_fixture(scope.beaver, colony, :builder, :pending)

      assert Colonies.fetch_membership(scope, colony.id) == {:error, :not_found}
    end

    test "a colony that doesn't exist is not found", %{scope: scope} do
      assert Colonies.fetch_membership(scope, Ecto.UUID.generate()) == {:error, :not_found}
    end

    test "an id that isn't a UUID is not found", %{scope: scope} do
      assert Colonies.fetch_membership(scope, "42") == {:error, :not_found}
    end
  end

  describe "list_members/1" do
    test "lists only the scope's colony's approved members" do
      scope = colony_scope_fixture()
      lodge_keeper = beaver_fixture()
      membership_fixture(lodge_keeper, scope.colony, :lodge_keeper)
      membership_fixture(beaver_fixture(), scope.colony, :builder, :pending)
      other_scope = colony_scope_fixture()

      members = Colonies.list_members(scope)

      assert Enum.map(members, & &1.beaver.id) |> Enum.sort() ==
               Enum.sort([scope.beaver.id, lodge_keeper.id])

      refute other_scope.beaver.id in Enum.map(members, & &1.beaver.id)
    end

    test "can't be called without a colony" do
      assert_raise FunctionClauseError, fn -> Colonies.list_members(beaver_scope_fixture()) end
    end
  end

  describe "rename_colony/2" do
    test "renames the scope's own colony and no other" do
      scope = colony_scope_fixture()
      other_scope = colony_scope_fixture()

      assert {:ok, %Colony{name: "Klamath"}} = Colonies.rename_colony(scope, %{name: "Klamath"})
      assert {:ok, other} = Colonies.fetch_membership(other_scope, other_scope.colony.id)
      assert other.colony.name == other_scope.colony.name
    end

    test "is refused below Dam Developer, whatever page called it" do
      for role <- [:builder, :lodge_keeper] do
        scope = colony_scope_fixture(role)
        assert Colonies.rename_colony(scope, %{name: "Mine now"}) == {:error, :unauthorized}
      end
    end

    test "is refused without a colony" do
      assert Colonies.rename_colony(beaver_scope_fixture(), %{name: "x"}) ==
               {:error, :unauthorized}
    end
  end
end
