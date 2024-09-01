defmodule Chess.Games.Move do
  use Ecto.Schema
  import Ecto.Changeset

  schema "moves" do
    field :move_number, :integer
    field :color, :string
    field :piece, :string
    field :from, :string
    field :to, :string
    field :move_code, :string
    field :promotion, :string, default: nil
    field :capture, :string, default: nil
    field :check, :boolean, default: false
    field :mate, :boolean, default: false
    field :draw, :boolean, default: false
    
    belongs_to :game, Chess.Games.Game

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(move, attrs) do
    move
    |> cast(attrs, [:move_number, :game_id, :color, :piece, :from, :to, :promotion, :capture, :check, :mate, :draw, :move_code])
    |> validate_required([:move_number, :game_id, :color, :piece, :from, :to, :move_code])
    |> validate_number(:move_number, greater_than: 0)
    |> validate_inclusion(:color, ["white", "black"])
    |> validate_position
    |> validate_piece_format
  end

  defp validate_position(changes) do
    changes
    |> validate_format(:from, ~r/^[a-h][1-8]$/)
    |> validate_format(:to, ~r/^[a-h][1-8]$/)
  end

  defp validate_piece_format(changes) do
    changes
    |> validate_inclusion(:piece, ["P", "N", "B", "R", "Q", "K"])
    |> validate_inclusion(:capture, ["P", "N", "B", "R", "Q", nil])
    |> validate_inclusion(:promotion, ["N", "B", "R", "Q", nil])
  end
end
