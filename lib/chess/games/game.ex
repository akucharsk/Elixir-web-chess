defmodule Chess.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  alias Chess.Accounts.User

  schema "games" do
    field :fen, :string
    field :white_score, :decimal
    field :black_score, :decimal
    field :result_reason, :string
    field :white_time, :time
    field :black_time, :time

    belongs_to :winner, User, foreign_key: :winner_id
    belongs_to :white, User, foreign_key: :white_id
    belongs_to :black, User, foreign_key: :black_id

    has_many :moves, Chess.Games.Move

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:white_id, :black_id, :fen, :winner_id, :white_score, :black_score, :result_reason])
    |> validate_required([:fen])
  end
end
