defmodule BeaverColony.Building.Signup do
  @moduledoc """
  A beaver signed up to help on a shift. Its colony is the shift's.

  Never cast from user input: `BeaverColony.Building.sign_up/2` sets both ids, the
  beaver from the scope and the shift after checking it's in the scope's colony.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "signups" do
    belongs_to :shift, BeaverColony.Building.Shift
    belongs_to :beaver, BeaverColony.Accounts.Beaver

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def insert_changeset(%__MODULE__{} = signup) do
    signup
    |> change()
    |> unique_constraint([:shift_id, :beaver_id], message: "already signed up")
  end
end
