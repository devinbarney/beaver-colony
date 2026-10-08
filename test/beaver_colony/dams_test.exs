defmodule BeaverColony.DamsTest do
  use BeaverColony.DataCase

  alias BeaverColony.Dams

  describe "sticks" do
    alias BeaverColony.Dams.Stick

    import BeaverColony.ColoniesFixtures, only: [colony_scope_fixture: 0]
    import BeaverColony.DamsFixtures

    @invalid_attrs %{x: nil, length: nil}

    test "list_sticks/1 returns all scoped sticks" do
      scope = colony_scope_fixture()
      other_scope = colony_scope_fixture()
      stick = stick_fixture(scope)
      other_stick = stick_fixture(other_scope)
      assert Dams.list_sticks(scope) == [stick]
      assert Dams.list_sticks(other_scope) == [other_stick]
    end

    test "get_stick!/2 returns the stick with given id" do
      scope = colony_scope_fixture()
      stick = stick_fixture(scope)
      other_scope = colony_scope_fixture()
      assert Dams.get_stick!(scope, stick.id) == stick
      assert_raise Ecto.NoResultsError, fn -> Dams.get_stick!(other_scope, stick.id) end
    end

    test "create_stick/2 with valid data creates a stick" do
      valid_attrs = %{x: 42, length: 42}
      scope = colony_scope_fixture()

      assert {:ok, %Stick{} = stick} = Dams.create_stick(scope, valid_attrs)
      assert stick.x == 42
      assert stick.length == 42
      assert stick.colony_id == scope.colony.id
    end

    test "create_stick/2 with invalid data returns error changeset" do
      scope = colony_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Dams.create_stick(scope, @invalid_attrs)
    end

    test "update_stick/3 with valid data updates the stick" do
      scope = colony_scope_fixture()
      stick = stick_fixture(scope)
      update_attrs = %{x: 43, length: 43}

      assert {:ok, %Stick{} = stick} = Dams.update_stick(scope, stick, update_attrs)
      assert stick.x == 43
      assert stick.length == 43
    end

    test "update_stick/3 with invalid scope raises" do
      scope = colony_scope_fixture()
      other_scope = colony_scope_fixture()
      stick = stick_fixture(scope)

      assert_raise MatchError, fn ->
        Dams.update_stick(other_scope, stick, %{})
      end
    end

    test "update_stick/3 with invalid data returns error changeset" do
      scope = colony_scope_fixture()
      stick = stick_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Dams.update_stick(scope, stick, @invalid_attrs)
      assert stick == Dams.get_stick!(scope, stick.id)
    end

    test "delete_stick/2 deletes the stick" do
      scope = colony_scope_fixture()
      stick = stick_fixture(scope)
      assert {:ok, %Stick{}} = Dams.delete_stick(scope, stick)
      assert_raise Ecto.NoResultsError, fn -> Dams.get_stick!(scope, stick.id) end
    end

    test "delete_stick/2 with invalid scope raises" do
      scope = colony_scope_fixture()
      other_scope = colony_scope_fixture()
      stick = stick_fixture(scope)
      assert_raise MatchError, fn -> Dams.delete_stick(other_scope, stick) end
    end

    test "change_stick/2 returns a stick changeset" do
      scope = colony_scope_fixture()
      stick = stick_fixture(scope)
      assert %Ecto.Changeset{} = Dams.change_stick(scope, stick)
    end
  end
end
