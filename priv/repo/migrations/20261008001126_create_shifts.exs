defmodule BeaverColony.Repo.Migrations.CreateShifts do
  use Ecto.Migration

  def change do
    create table(:shifts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :starts_at, :naive_datetime, null: false
      add :hours, :integer, null: false
      add :needed, :integer, null: false
      add :site_id, references(:sites, on_delete: :delete_all, type: :binary_id), null: false

      add :colony_id, references(:colonies, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:shifts, [:colony_id, :starts_at])
    create index(:shifts, [:site_id])

    # A beaver signed up to help on a shift. The colony comes through the shift.
    create table(:signups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :shift_id, references(:shifts, on_delete: :delete_all, type: :binary_id), null: false
      add :beaver_id, references(:beavers, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:signups, [:shift_id, :beaver_id])
    create index(:signups, [:beaver_id])
  end
end
