defmodule BeaverColony.Colonies.Colony do
  @moduledoc """
  A colony of beavers: the tenant. Everything a colony owns carries its `colony_id`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "colonies" do
    field :name, :string

    has_many :memberships, BeaverColony.Colonies.Membership

    timestamps(type: :utc_datetime)
  end

  def changeset(colony, attrs) do
    colony
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, max: 80)
  end
end
