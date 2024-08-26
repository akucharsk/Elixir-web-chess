defmodule Chess.Repo.Migrations.CreateMoves do
  use Ecto.Migration

  def change do
    create table(:moves) do
      add :move_number, :integer
      add :white_move, :string
      add :black_move, :string
      add :game_id, references(:games, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:moves, [:game_id])

    alter table(:games) do
      remove :pen
    end
  end
end
