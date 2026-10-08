defmodule BeaverColony.Dams.Stick do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "sticks" do
    field :x, :integer
    field :length, :integer
    field :colony_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(stick, attrs, colony_scope) do
    stick
    |> cast(attrs, [:x, :length])
    |> validate_required([:x, :length])
    |> put_change(:colony_id, colony_scope.colony.id)
  end
end
