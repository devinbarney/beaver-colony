defmodule BeaverColony.Building.Site do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "sites" do
    field :name, :string
    field :river_mile, :float
    field :notes, :string
    field :colony_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(site, attrs, colony_scope) do
    site
    |> cast(attrs, [:name, :river_mile, :notes])
    |> validate_required([:name, :river_mile, :notes])
    |> put_change(:colony_id, colony_scope.colony.id)
  end
end
