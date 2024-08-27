defmodule Chess.Repo.Migrations.MoveTimestamps do
  use Ecto.Migration

  def change do
    alter table(:games) do
      remove :inserted_at
      remove :updated_at

      add :black_score, :decimal, precision: 3, scale: 1

      timestamps(type: :utc_datetime)
    end

    create index(:games, [:winner_id])
  end
end
