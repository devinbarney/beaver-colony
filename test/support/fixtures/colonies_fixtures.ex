defmodule BeaverColony.ColoniesFixtures do
  @moduledoc """
  Test helpers for colonies and memberships.
  """

  import BeaverColony.AccountsFixtures

  alias BeaverColony.{Colonies, Repo}
  alias BeaverColony.Accounts.Scope
  alias BeaverColony.Colonies.Membership

  def unique_colony_name, do: "Colony #{System.unique_integer([:positive])}"

  @doc """
  A colony founded by the beaver in `scope` (a new beaver by default), who becomes its
  Dam Developer.
  """
  def colony_fixture(scope \\ beaver_scope_fixture(), attrs \\ %{}) do
    {:ok, colony} =
      Colonies.create_colony(scope, Enum.into(attrs, %{name: unique_colony_name()}))

    colony
  end

  @doc """
  Puts `beaver` in `colony` with `role`, approved unless `status` says otherwise.
  """
  def membership_fixture(beaver, colony, role, status \\ :approved) do
    Repo.insert!(%Membership{
      beaver_id: beaver.id,
      colony_id: colony.id,
      role: role,
      status: status
    })
  end

  @doc """
  A scope for a new beaver acting with `role` in a new colony. Each call makes a
  different colony, which is what isolation tests need.
  """
  def colony_scope_fixture(role \\ :dam_developer) do
    founder = beaver_scope_fixture()
    colony = colony_fixture(founder)

    if role == :dam_developer do
      Scope.put_colony(founder, colony, :dam_developer)
    else
      beaver = beaver_fixture()
      membership_fixture(beaver, colony, role)
      Scope.put_colony(Scope.for_beaver(beaver), colony, role)
    end
  end
end
