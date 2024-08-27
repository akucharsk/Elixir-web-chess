defmodule Chess.Repo.Migrations.AlterGame do
  use Ecto.Migration

  def change do
    alter table(:games) do
      remove :white_id
      remove :black_id

      add :white_id, references(:users, on_delete: :nilify_all)
      add :black_id, references(:users, on_delete: :nilify_all)
      add :winner_id, references(:users, on_delete: :nilify_all)
      add :white_score, :decimal, precision: 3, scale: 1

      remove :score
      remove :result
    end
  end
end
