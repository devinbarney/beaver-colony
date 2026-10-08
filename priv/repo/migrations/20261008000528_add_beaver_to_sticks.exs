defmodule BeaverColony.Repo.Migrations.AddBeaverToSticks do
  use Ecto.Migration

  # The generated migration left every column nullable and didn't record who placed a
  # stick. It has already run, so this follows it rather than editing it.
  def change do
    alter table(:sticks) do
      modify :colony_id, :binary_id, null: false, from: {:binary_id, null: true}
      modify :x, :integer, null: false, from: {:integer, null: true}
      modify :length, :integer, null: false, from: {:integer, null: true}

      # Keep the stick in the dam if the beaver who placed it leaves.
      add :beaver_id, references(:beavers, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:sticks, [:beaver_id])
  end
end
