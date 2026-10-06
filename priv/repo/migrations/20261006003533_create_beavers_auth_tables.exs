defmodule BeaverColony.Repo.Migrations.CreateBeaversAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:beavers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:beavers, [:email])

    create table(:beavers_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :beaver_id, references(:beavers, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:beavers_tokens, [:beaver_id])
    create unique_index(:beavers_tokens, [:context, :token])
  end
end
