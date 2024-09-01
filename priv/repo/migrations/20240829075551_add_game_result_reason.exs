defmodule Chess.Repo.Migrations.AddGameResultReason do
  use Ecto.Migration

  def change do
    alter table :games do
      remove :inserted_at
      remove :updated_at
      
      add :result_reason, :string

      timestamps(type: :utc_datetime)
    end
  end
end
