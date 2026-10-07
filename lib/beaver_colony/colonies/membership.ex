defmodule BeaverColony.Colonies.Membership do
  @moduledoc """
  A beaver's place in one colony: their role there, and whether they've been let in.

  Only an `:approved` membership opens the colony. A `:pending` one is a request to join.

  `beaver_id`, `colony_id`, `role` and `status` are never cast from user input. The
  `BeaverColony.Colonies` context sets them from the caller's scope and its own rules.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias BeaverColony.Colonies.Policy

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memberships" do
    field :role, Ecto.Enum, values: Policy.roles()
    field :status, Ecto.Enum, values: [:pending, :approved]

    belongs_to :beaver, BeaverColony.Accounts.Beaver
    belongs_to :colony, BeaverColony.Colonies.Colony

    timestamps(type: :utc_datetime)
  end

  @doc """
  Turns the database's constraints into changeset errors for an insert: a beaver
  already in (or asking to join) the colony, or a colony that doesn't exist.
  """
  def insert_changeset(%__MODULE__{} = membership) do
    membership
    |> change()
    |> unique_constraint([:beaver_id, :colony_id],
      message: "already a member or waiting to join"
    )
    |> foreign_key_constraint(:colony_id)
  end
end
