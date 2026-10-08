defmodule BeaverColony.Demo do
  @moduledoc """
  Demo beavers that readers of the guide can sign in as without a password, one per
  role, in a demo colony.

    * Willamette Colony: `dam@example.com` (Dam Developer), `keeper@example.com`
      (Lodge Keeper), `builder@example.com` (Builder)
    * Klamath Colony: `keeper@example.com` (Dam Developer), with `builder@example.com`
      asking to join

  All share the password `beavers build dams`, for signing in the ordinary way too.

  Signing in as a demo beaver needs no password, so it is **off** unless configured:

      config :beaver_colony, :demo, enabled: true

  Only turn it on where these accounts hold nothing that matters, such as a public demo
  site. `reset!/0` puts the demo data back as it started.
  """

  import Ecto.Query

  alias BeaverColony.{Accounts, Building, Colonies, Dams, Repo}
  alias BeaverColony.Accounts.{Beaver, Scope}
  alias BeaverColony.Colonies.{Colony, Membership}

  @password "beavers build dams"
  @beavers %{
    dam_developer: "dam@example.com",
    lodge_keeper: "keeper@example.com",
    builder: "builder@example.com"
  }
  @home_colony "Willamette Colony"

  @doc "Whether signing in as a demo beaver is allowed here."
  def enabled?, do: Application.get_env(:beaver_colony, :demo, [])[:enabled] == true

  @doc "The roles a reader can try, lowest first."
  def roles, do: [:builder, :lodge_keeper, :dam_developer]

  @doc """
  The demo beaver to sign in as for `role`, and the path to land on: their page in
  Willamette Colony. `nil` when demos are off or the demo data isn't there.
  """
  def sign_in_as(role) do
    with true <- enabled?(),
         email when is_binary(email) <- @beavers[role],
         %Beaver{} = beaver <- Accounts.get_beaver_by_email(email) do
      landing =
        Scope.for_beaver(beaver)
        |> Colonies.list_memberships()
        |> Enum.find(&(&1.colony.name == @home_colony))
        |> case do
          nil -> "/me/colonies"
          membership -> "/colonies/#{membership.colony.id}"
        end

      {beaver, landing}
    else
      _ -> nil
    end
  end

  @doc """
  Creates the demo beavers and colonies. Does nothing to colonies that already exist,
  so it is safe to run more than once.
  """
  def seed! do
    dam = demo_beaver!(@beavers.dam_developer)
    keeper = demo_beaver!(@beavers.lodge_keeper)
    builder = demo_beaver!(@beavers.builder)

    if Colonies.list_memberships(Scope.for_beaver(dam)) == [] do
      {:ok, willamette} = Colonies.create_colony(Scope.for_beaver(dam), %{name: @home_colony})
      {:ok, klamath} = Colonies.create_colony(Scope.for_beaver(keeper), %{name: "Klamath Colony"})

      for {member, role} <- [{keeper, :lodge_keeper}, {builder, :builder}] do
        Repo.insert!(%Membership{
          beaver_id: member.id,
          colony_id: willamette.id,
          role: role,
          status: :approved
        })
      end

      {:ok, _} = Colonies.request_to_join(Scope.for_beaver(builder), klamath.id)

      # A dam already under way, so the first visit has something to look at.
      for {beaver, role, x, length} <- [
            {dam, :dam_developer, 0, 30},
            {builder, :builder, 30, 30},
            {keeper, :lodge_keeper, 60, 30},
            {builder, :builder, 10, 25},
            {dam, :dam_developer, 40, 25},
            {keeper, :lodge_keeper, 25, 20}
          ] do
        scope = Scope.put_colony(Scope.for_beaver(beaver), willamette, role)
        {:ok, _} = Dams.create_stick(scope, %{x: x, length: length})
      end

      keeper_scope = Scope.put_colony(Scope.for_beaver(keeper), willamette, :lodge_keeper)

      for {name, mile, notes} <- [
            {"Mill Creek Narrows", 12.5, "Narrow and shallow. Good alder on both banks."},
            {"Beaver Slough", 18.0, "Slow water, deep mud. Bring long sticks."}
          ] do
        {:ok, _} =
          Building.create_site(keeper_scope, %{name: name, river_mile: mile, notes: notes})
      end
    end

    :ok
  end

  @doc """
  Puts the demo back as it started: removes every colony a demo beaver founded and every
  membership a demo beaver holds, then seeds again.
  """
  def reset! do
    emails = Map.values(@beavers)

    Repo.transact(fn ->
      demo_ids = Repo.all(from b in Beaver, where: b.email in ^emails, select: b.id)

      Repo.delete_all(
        from c in Colony,
          join: m in assoc(c, :memberships),
          where: m.beaver_id in ^demo_ids and m.role == :dam_developer
      )

      Repo.delete_all(from m in Membership, where: m.beaver_id in ^demo_ids)
      {:ok, seed!()}
    end)
  end

  defp demo_beaver!(email) do
    beaver =
      Accounts.get_beaver_by_email(email) ||
        (
          {:ok, beaver} = Accounts.register_beaver(%{email: email})
          beaver
        )

    {:ok, {beaver, _}} = Accounts.update_beaver_password(beaver, %{password: @password})
    Repo.update!(Ecto.Changeset.change(beaver, confirmed_at: DateTime.utc_now(:second)))
  end
end
