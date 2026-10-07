# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     BeaverColony.Repo.insert!(%BeaverColony.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Demo beavers, one per role, all with the password "beavers build dams".
#
#   Willamette Colony: dam@example.com (Dam Developer), keeper@example.com (Lodge
#                      Keeper), builder@example.com (Builder)
#   Klamath Colony:    keeper@example.com (Dam Developer); builder@example.com is
#                      asking to join
#
# Safe to run again: existing beavers are reused.
alias BeaverColony.{Accounts, Colonies, Repo}
alias BeaverColony.Accounts.Scope
alias BeaverColony.Colonies.Membership

password = "beavers build dams"

beaver = fn email ->
  beaver =
    Accounts.get_beaver_by_email(email) ||
      (
        {:ok, beaver} = Accounts.register_beaver(%{email: email})
        beaver
      )

  {:ok, {beaver, _}} = Accounts.update_beaver_password(beaver, %{password: password})
  Repo.update!(Ecto.Changeset.change(beaver, confirmed_at: DateTime.utc_now(:second)))
end

dam = beaver.("dam@example.com")
keeper = beaver.("keeper@example.com")
builder = beaver.("builder@example.com")

if Colonies.list_memberships(Scope.for_beaver(dam)) == [] do
  {:ok, willamette} = Colonies.create_colony(Scope.for_beaver(dam), %{name: "Willamette Colony"})
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
end
