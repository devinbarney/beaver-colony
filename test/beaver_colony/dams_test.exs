defmodule BeaverColony.DamsTest do
  use BeaverColony.DataCase

  alias BeaverColony.Dams

  describe "sticks" do
    alias BeaverColony.Dams.Stick

    import BeaverColony.ColoniesFixtures, only: [colony_scope_fixture: 0, colony_scope_fixture: 1]
    import BeaverColony.DamsFixtures

    @invalid_attrs %{x: nil, length: nil}

    # These two came from the generator: the colony scope's isolation, for free.
    test "list_sticks/1 returns all scoped sticks" do
      scope = colony_scope_fixture()
      other_scope = colony_scope_fixture()
      stick = stick_fixture(scope)
      other_stick = stick_fixture(other_scope)
      assert Enum.map(Dams.list_sticks(scope), & &1.id) == [stick.id]
      assert Enum.map(Dams.list_sticks(other_scope), & &1.id) == [other_stick.id]
    end

    test "get_stick!/2 returns the stick with given id" do
      scope = colony_scope_fixture()
      stick = stick_fixture(scope)
      other_scope = colony_scope_fixture()
      assert Dams.get_stick!(scope, stick.id) == stick
      assert_raise Ecto.NoResultsError, fn -> Dams.get_stick!(other_scope, stick.id) end
    end

    # What we added: who placed it, what fits, and who may.
    test "create_stick/2 records the colony and the beaver who placed it" do
      scope = colony_scope_fixture(:builder)

      assert {:ok, %Stick{} = stick} = Dams.create_stick(scope, %{x: 10, length: 20})
      assert stick.colony_id == scope.colony.id
      assert stick.beaver_id == scope.beaver.id
    end

    test "create_stick/2 ignores a colony or beaver in the params" do
      scope = colony_scope_fixture(:builder)
      other = colony_scope_fixture()

      {:ok, stick} =
        Dams.create_stick(scope, %{
          x: 10,
          length: 20,
          colony_id: other.colony.id,
          beaver_id: other.beaver.id
        })

      assert stick.colony_id == scope.colony.id
      assert stick.beaver_id == scope.beaver.id
    end

    test "create_stick/2 with invalid data returns error changeset" do
      scope = colony_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Dams.create_stick(scope, @invalid_attrs)
    end

    test "create_stick/2 refuses a stick that sticks out past the end of the dam" do
      scope = colony_scope_fixture()
      assert {:error, changeset} = Dams.create_stick(scope, %{x: 90, length: 20})
      assert "the stick would stick out past the end of the dam" in errors_on(changeset).x
    end

    test "delete_stick/2 needs a lodge keeper" do
      builder = colony_scope_fixture(:builder)
      stick = stick_fixture(builder)
      assert Dams.delete_stick(builder, stick) == {:error, :unauthorized}

      keeper = colony_scope_fixture(:lodge_keeper)
      keepers_stick = stick_fixture(keeper)
      assert {:ok, %Stick{}} = Dams.delete_stick(keeper, keepers_stick)
      assert_raise Ecto.NoResultsError, fn -> Dams.get_stick!(keeper, keepers_stick.id) end
    end

    test "delete_stick/2 with another colony's stick raises" do
      scope = colony_scope_fixture()
      other_scope = colony_scope_fixture()
      stick = stick_fixture(scope)
      assert_raise MatchError, fn -> Dams.delete_stick(other_scope, stick) end
    end

    test "placing and removing are broadcast to the colony" do
      scope = colony_scope_fixture()
      Dams.subscribe_sticks(scope)

      stick = stick_fixture(scope)
      assert_receive {:created, %Stick{id: id}} when id == stick.id

      {:ok, _} = Dams.delete_stick(scope, stick)
      assert_receive {:deleted, %Stick{id: ^id}}
    end
  end

  describe "layout/1" do
    alias BeaverColony.Dams.Stick

    defp stick(x, length), do: %Stick{x: x, length: length}

    defp rows(sticks), do: sticks |> Dams.layout() |> Enum.map(fn {_stick, row} -> row end)

    test "sticks side by side all rest on the riverbed" do
      assert rows([stick(0, 10), stick(10, 10), stick(20, 10)]) == [0, 0, 0]
    end

    test "a stick rests on the highest earlier stick it overlaps" do
      assert rows([stick(0, 10), stick(5, 10), stick(0, 30)]) == [0, 1, 2]
    end

    test "a stick that bridges a gap rests on the taller side" do
      assert rows([stick(0, 10), stick(0, 10), stick(20, 10), stick(5, 20)]) == [0, 1, 0, 2]
    end
  end
end
