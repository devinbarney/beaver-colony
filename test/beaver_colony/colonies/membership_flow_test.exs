defmodule BeaverColony.Colonies.MembershipFlowTest do
  use BeaverColony.DataCase, async: true

  import BeaverColony.AccountsFixtures
  import BeaverColony.ColoniesFixtures

  alias BeaverColony.Colonies

  describe "request_to_join/2" do
    test "asks to join as a pending Builder" do
      scope = beaver_scope_fixture()
      colony = colony_fixture()

      assert {:ok, membership} = Colonies.request_to_join(scope, colony.id)
      assert membership.role == :builder
      assert membership.status == :pending
      assert Colonies.fetch_membership(scope, colony.id) == {:error, :not_found}
    end

    test "can't ask twice, or join a colony you're already in" do
      scope = beaver_scope_fixture()
      colony = colony_fixture()
      {:ok, _} = Colonies.request_to_join(scope, colony.id)

      assert {:error, changeset} = Colonies.request_to_join(scope, colony.id)
      assert "already a member or waiting to join" in errors_on(changeset).beaver_id

      assert {:error, _} = Colonies.request_to_join(scope, colony_fixture(scope).id)
    end

    test "a colony that doesn't exist can't be joined" do
      scope = beaver_scope_fixture()
      assert Colonies.request_to_join(scope, "nope") == {:error, :not_found}
      assert {:error, %Ecto.Changeset{}} = Colonies.request_to_join(scope, Ecto.UUID.generate())
    end
  end

  describe "list_other_colonies/1" do
    test "lists colonies the beaver isn't in, marking the ones they asked to join" do
      scope = beaver_scope_fixture()
      _mine = colony_fixture(scope)
      asked = colony_fixture()
      {:ok, _} = Colonies.request_to_join(scope, asked.id)
      stranger = colony_fixture()

      others = Map.new(Colonies.list_other_colonies(scope), fn {c, status} -> {c.id, status} end)
      assert others == %{asked.id => :pending, stranger.id => nil}
    end
  end

  describe "approve_membership/2 and decline_membership/2" do
    setup do
      scope = colony_scope_fixture(:lodge_keeper)
      {:ok, request} = Colonies.request_to_join(beaver_scope_fixture(), scope.colony.id)
      %{scope: scope, request: request}
    end

    test "a lodge keeper lets a beaver in", %{scope: scope, request: request} do
      assert {:ok, %{status: :approved}} = Colonies.approve_membership(scope, request.id)
      assert Enum.any?(Colonies.list_members(scope), &(&1.id == request.id))
      assert Colonies.list_pending(scope) == []
    end

    test "a lodge keeper turns a request down", %{scope: scope, request: request} do
      assert {:ok, _} = Colonies.decline_membership(scope, request.id)
      assert Colonies.list_pending(scope) == []
    end

    test "a builder can't let anyone in", %{scope: scope, request: request} do
      builder = beaver_fixture()
      membership_fixture(builder, scope.colony, :builder)
      builder_scope = put_colony(builder, scope.colony, :builder)

      assert Colonies.approve_membership(builder_scope, request.id) == {:error, :unauthorized}
    end

    test "another colony's request is not found", %{request: request} do
      other = colony_scope_fixture(:lodge_keeper)
      assert Colonies.approve_membership(other, request.id) == {:error, :not_found}
      assert Colonies.decline_membership(other, request.id) == {:error, :not_found}
    end
  end

  describe "change_role/3" do
    setup do
      scope = colony_scope_fixture(:dam_developer)
      builder = beaver_fixture()
      membership = membership_fixture(builder, scope.colony, :builder)
      %{scope: scope, membership: membership}
    end

    test "the dam developer promotes a builder", %{scope: scope, membership: membership} do
      assert {:ok, %{role: :lodge_keeper}} =
               Colonies.change_role(scope, membership.id, :lodge_keeper)
    end

    test "no one can make another dam developer", %{scope: scope, membership: membership} do
      assert Colonies.change_role(scope, membership.id, :dam_developer) == {:error, :unauthorized}
    end

    test "an unknown role is refused", %{scope: scope, membership: membership} do
      assert Colonies.change_role(scope, membership.id, nil) == {:error, :unauthorized}
    end

    test "a lodge keeper can't change roles", %{scope: scope, membership: membership} do
      keeper = beaver_fixture()
      membership_fixture(keeper, scope.colony, :lodge_keeper)
      keeper_scope = put_colony(keeper, scope.colony, :lodge_keeper)

      assert Colonies.change_role(keeper_scope, membership.id, :builder) ==
               {:error, :unauthorized}
    end

    test "another colony's member is not found", %{membership: membership} do
      assert Colonies.change_role(colony_scope_fixture(), membership.id, :lodge_keeper) ==
               {:error, :not_found}
    end
  end

  describe "remove_member/2" do
    test "a lodge keeper removes a builder, but not another lodge keeper" do
      scope = colony_scope_fixture(:lodge_keeper)
      builder = membership_fixture(beaver_fixture(), scope.colony, :builder)
      peer = membership_fixture(beaver_fixture(), scope.colony, :lodge_keeper)

      assert {:ok, _} = Colonies.remove_member(scope, builder.id)
      assert Colonies.remove_member(scope, peer.id) == {:error, :unauthorized}
    end

    test "another colony's member is not found" do
      scope = colony_scope_fixture()
      builder = membership_fixture(beaver_fixture(), colony_fixture(), :builder)

      assert Colonies.remove_member(scope, builder.id) == {:error, :not_found}
    end
  end

  describe "live updates" do
    test "the beaver and the colony both hear about a change" do
      scope = colony_scope_fixture(:lodge_keeper)
      joiner = beaver_scope_fixture()
      Colonies.subscribe_my_memberships(joiner)
      Colonies.subscribe_colony_memberships(scope)

      {:ok, request} = Colonies.request_to_join(joiner, scope.colony.id)
      colony_id = scope.colony.id
      assert_receive {:membership_changed, ^colony_id}
      assert_receive {:memberships_changed, ^colony_id}

      {:ok, _} = Colonies.approve_membership(scope, request.id)
      assert_receive {:membership_changed, ^colony_id}
    end
  end

  defp put_colony(beaver, colony, role) do
    BeaverColony.Accounts.Scope.put_colony(beaver_scope_fixture(beaver), colony, role)
  end
end
