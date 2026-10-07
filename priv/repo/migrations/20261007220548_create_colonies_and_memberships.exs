defmodule BeaverColony.Repo.Migrations.CreateColoniesAndMemberships do
  use Ecto.Migration

  def change do
    create table(:colonies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :beaver_id, references(:beavers, type: :binary_id, on_delete: :delete_all), null: false

      add :colony_id, references(:colonies, type: :binary_id, on_delete: :delete_all), null: false

      add :role, :string, null: false
      add :status, :string, null: false

      timestamps(type: :utc_datetime)
    end

    # One membership per beaver per colony: a beaver holds exactly one role in each colony.
    create unique_index(:memberships, [:beaver_id, :colony_id])
    create index(:memberships, [:colony_id])
  end
end
