defmodule BeaverColony.Accounts.ScopeTest do
  use BeaverColony.DataCase, async: true

  import BeaverColony.AccountsFixtures
  import BeaverColony.ColoniesFixtures

  alias BeaverColony.Accounts.Scope

  test "put_colony/3 narrows a beaver's scope to a colony and role" do
    scope = beaver_scope_fixture()
    colony = colony_fixture(scope)

    assert %Scope{beaver: beaver, colony: ^colony, role: :builder} =
             Scope.put_colony(scope, colony, :builder)

    assert beaver == scope.beaver
  end

  test "can?/2 asks the policy about the scope's role" do
    assert Scope.can?(colony_scope_fixture(:lodge_keeper), :manage_members)
    refute Scope.can?(colony_scope_fixture(:builder), :manage_members)
  end

  test "can?/2 is false without a colony, whatever the ability" do
    scope = beaver_scope_fixture()
    refute Scope.can?(scope, :view_colony)
    refute Scope.can?(nil, :view_colony)
  end
end
