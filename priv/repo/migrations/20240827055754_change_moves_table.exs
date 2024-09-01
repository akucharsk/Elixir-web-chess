defmodule Chess.Repo.Migrations.ChangeMovesTable do
  use Ecto.Migration

  def change do
    alter table :moves do
      remove :white_move
      remove :black_move
      remove :inserted_at
      remove :updated_at

      add :color, :string
      add :piece, :string
      add :from, :string
      add :to, :string
      add :promotion, :string
      add :capture, :string
      add :check, :boolean
      add :mate, :boolean
      add :draw, :boolean

      timestamps(type: :utc_datetime)
    end

    create unique_index :moves, [:move_number, :color]
  end
end
