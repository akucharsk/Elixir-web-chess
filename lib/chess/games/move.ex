defmodule Chess.Games.Move do
  use Ecto.Schema
  import Ecto.Changeset

  schema "moves" do
    field :move_number, :integer
    field :white_move, :string
    field :black_move, :string
    
    belongs_to :game, Chess.Games.Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(move, attrs) do
    move
    |> cast(attrs, [:move_number, :white_move, :black_move, :game_id])
    |> validate_required([:move_number, :white_move, :game_id])
    |> validate_number(:move_number, greater_than: 0)
  end
end
