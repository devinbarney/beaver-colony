defmodule BeaverColony.Repo.Migrations.CreateSticks do
  use Ecto.Migration

  def change do
    create table(:sticks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :x, :integer
      add :length, :integer
      add :colony_id, references(:colonies, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:sticks, [:colony_id])
  end
end
