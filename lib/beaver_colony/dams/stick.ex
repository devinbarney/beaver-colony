defmodule BeaverColony.Dams.Stick do
  @moduledoc """
  One stick in a colony's dam. The dam is 100 units wide: a stick starts at `x` and is
  `length` units long. Where it ends up vertically isn't stored. It rests on whatever
  was placed under it first (see `BeaverColony.Dams.layout/1`).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @dam_width 100
  @lengths 5..30

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "sticks" do
    field :x, :integer
    field :length, :integer
    field :colony_id, :binary_id

    belongs_to :beaver, BeaverColony.Accounts.Beaver

    timestamps(type: :utc_datetime)
  end

  def dam_width, do: @dam_width
  def lengths, do: @lengths

  @doc false
  def changeset(stick, attrs, colony_scope) do
    stick
    |> cast(attrs, [:x, :length])
    |> validate_required([:x, :length])
    |> validate_number(:length, greater_than_or_equal_to: @lengths.first)
    |> validate_number(:length, less_than_or_equal_to: @lengths.last)
    |> validate_number(:x, greater_than_or_equal_to: 0)
    |> validate_fits()
    |> put_change(:colony_id, colony_scope.colony.id)
    |> put_change(:beaver_id, colony_scope.beaver.id)
  end

  defp validate_fits(changeset) do
    x = get_field(changeset, :x)
    length = get_field(changeset, :length)

    if is_integer(x) and is_integer(length) and x + length > @dam_width,
      do: add_error(changeset, :x, "the stick would stick out past the end of the dam"),
      else: changeset
  end
end
