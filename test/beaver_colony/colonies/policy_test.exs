defmodule BeaverColony.Colonies.PolicyTest do
  use ExUnit.Case, async: true

  alias BeaverColony.Colonies.Policy

  test "a builder can only view the colony" do
    assert Policy.allows?(:builder, :view_colony)
    refute Policy.allows?(:builder, :manage_members)
    refute Policy.allows?(:builder, :manage_colony)
  end

  test "a lodge keeper can also manage members" do
    assert Policy.allows?(:lodge_keeper, :view_colony)
    assert Policy.allows?(:lodge_keeper, :manage_members)
    refute Policy.allows?(:lodge_keeper, :manage_colony)
  end

  test "a dam developer can do everything" do
    for ability <- Policy.abilities() do
      assert Policy.allows?(:dam_developer, ability)
    end
  end

  test "an unknown ability raises instead of quietly denying" do
    assert_raise KeyError, fn -> Policy.allows?(:dam_developer, :fly) end
  end
end
