defmodule Chess.Repo.Migrations.AddGameTimes do
  use Ecto.Migration

  def change do
    alter table(:games) do
      remove :inserted_at
      remove :updated_at

      add :white_time, :time, default: "00:00:00"
      add :black_time, :time, default: "00:00:00"

      timestamps(type: :utc_datetime)
    end
  end
end
