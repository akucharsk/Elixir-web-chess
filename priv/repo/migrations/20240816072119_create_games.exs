defmodule Chess.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :result, :integer
      add :score, :integer
      add :pen, :string
      add :fen, :string
      add :white_id, references(:users, on_delete: :nothing)
      add :black_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:games, [:white_id])
    create index(:games, [:black_id])
  end
end
