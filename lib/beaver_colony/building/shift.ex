defmodule BeaverColony.Building.Shift do
  @moduledoc """
  A stretch of building at one of the colony's sites: when it starts, how many hours it
  runs, and how many builders it needs. Times are river time (no time zone).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "shifts" do
    field :starts_at, :naive_datetime
    field :hours, :integer
    field :needed, :integer
    field :colony_id, :binary_id

    belongs_to :site, BeaverColony.Building.Site
    belongs_to :colony, BeaverColony.Colonies.Colony, define_field: false
    has_many :signups, BeaverColony.Building.Signup

    timestamps(type: :utc_datetime)
  end

  @doc """
  `site_id` isn't cast: it comes from the caller, so `BeaverColony.Building.create_shift/2`
  checks it belongs to the scope's colony and sets it itself.
  """
  def changeset(shift, attrs, colony_scope) do
    shift
    |> cast(attrs, [:starts_at, :hours, :needed])
    |> validate_required([:starts_at, :hours, :needed])
    |> validate_number(:hours, greater_than_or_equal_to: 1, less_than_or_equal_to: 8)
    |> validate_number(:needed, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> put_change(:colony_id, colony_scope.colony.id)
  end

  @doc "When the shift ends."
  def ends_at(%__MODULE__{starts_at: starts_at, hours: hours}),
    do: NaiveDateTime.add(starts_at, hours, :hour)
end
