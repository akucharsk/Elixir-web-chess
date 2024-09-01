defmodule Chess.Repo.Migrations.AddEntireMoveCodeColumn do
  use Ecto.Migration

  def change do
    alter table :moves do
      remove :inserted_at
      remove :updated_at

      add :move_code, :string, null: false
      modify :move_number, :integer, null: false
      modify :color, :string, null: false
      modify :piece, :string, null: false
      modify :from, :string, null: false
      modify :to, :string, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
