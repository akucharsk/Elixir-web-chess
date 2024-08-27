defmodule Chess.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias Chess.Repo

  alias Chess.Games.Game
  alias Chess.Accounts
  alias Chess.Chessboard
  alias Chess.FENParser

  @doc """
  Returns the list of games.

  ## Examples

      iex> list_games()
      [%Game{}, ...]

  """
  def list_games do
    Repo.all(Game)
  end

  @doc """
  Gets a single game.

  Raises `Ecto.NoResultsError` if the Game does not exist.

  ## Examples

      iex> get_game!(123)
      %Game{}

      iex> get_game!(456)
      ** (Ecto.NoResultsError)

  """
  def get_game!(id) do
    Game
    |> Repo.get!(id)
    |> Repo.preload(:moves)
  end

  @doc """
  Creates a game.

  ## Examples

      iex> create_game(%{field: value})
      {:ok, %Game{}}

      iex> create_game(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_game(attrs \\ %{}) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a game.

  ## Examples

      iex> update_game(game, %{field: new_value})
      {:ok, %Game{}}

      iex> update_game(game, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a game.

  ## Examples

      iex> delete_game(game)
      {:ok, %Game{}}

      iex> delete_game(game)
      {:error, %Ecto.Changeset{}}

  """
  def delete_game(%Game{} = game) do
    Repo.delete(game)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game changes.

  ## Examples

      iex> change_game(game)
      %Ecto.Changeset{data: %Game{}}

  """
  def change_game(%Game{} = game, attrs \\ %{}) do
    Game.changeset(game, attrs)
  end

  @doc """
    Fetches a game where a player is waiting for an opponent. If no such game is found, a new game is created.
  """
  def fetch_ready_game(user_id) do
    query = from g in Game,
            where: is_nil(g.white_id) or is_nil(g.black_id),
            limit: 1
    
    case Repo.one(query) do
      nil -> 
        atom = if Enum.random([0, 1]) == 0, do: :white_id, else: :black_id
        create_game(%{atom => user_id, fen: Chess.FENParser.base_fen})
      game -> fill_free_spot(game, user_id)
    end
  end

  defp fill_free_spot(game, user_id) do
    if is_nil(game.white_id) do
      update_game(game, %{white_id: user_id})
    else
      update_game(game, %{black_id: user_id})
    end
  end

  @doc """
    Checks if a game is ready to be played.
  """
  def ready_game?(%Game{white_id: nil} = game), do: false
  def ready_game?(%Game{black_id: nil} = game), do: false
  def ready_game?(_game), do: true


  alias Chess.Games.Move

  @doc """
  Returns the list of moves.

  ## Examples

      iex> list_moves()
      [%Move{}, ...]

  """
  def list_moves do
    Repo.all(Move)
  end

  @doc """
  Gets a single move.

  Raises `Ecto.NoResultsError` if the Move does not exist.

  ## Examples

      iex> get_move!(123)
      %Move{}

      iex> get_move!(456)
      ** (Ecto.NoResultsError)

  """
  def get_move!(id), do: Repo.get!(Move, id)

  @doc """
  Creates a move.

  ## Examples

      iex> create_move(%{field: value})
      {:ok, %Move{}}

      iex> create_move(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_move(attrs \\ %{}) do
    %Move{}
    |> Move.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
    Registers a move by the last move made, the fullmoves count and the game id.
    Creates a new move if white moves, and updates the last move if black moves.
  """
  def register_move(board, %{color: :white} = last_move, fullmoves, game_id) do
    %{game_id: game_id, move_number: fullmoves, 
      white_move: move_string(board, last_move) <> check_or_mate(last_move)}
    |> create_move
  end
  def register_move(board, %{color: :black} = last_move, fullmoves, game_id) do
    game_id
    |> get_game!
    |> Map.get(:moves)
    |> List.last
    |> update_move(%{black_move: move_string(board, last_move) <> check_or_mate(last_move)})
  end

  @doc """
  Updates a move.

  ## Examples

      iex> update_move(move, %{field: new_value})
      {:ok, %Move{}}

      iex> update_move(move, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_move(%Move{} = move, attrs) do
    move
    |> Move.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a move.

  ## Examples

      iex> delete_move(move)
      {:ok, %Move{}}

      iex> delete_move(move)
      {:error, %Ecto.Changeset{}}

  """
  def delete_move(%Move{} = move) do
    Repo.delete(move)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking move changes.

  ## Examples

      iex> change_move(move)
      %Ecto.Changeset{data: %Move{}}

  """
  def change_move(%Move{} = move, attrs \\ %{}) do
    Move.changeset(move, attrs)
  end

  defp move_string(_board, %{piece: :king, to: {_, _, :long_castling}}), do: "O-O-O"
  defp move_string(_board, %{piece: :king, to: {_, _, :short_castling}}), do: "O-O"
  defp move_string(_board, %{piece: :pawn, from: {from_row, from_col, _}, to: {to_row, to_col, :en_passant}}) do
    "#{from_col}#{from_row}-#{from_col}x#{to_col}#{to_row}e.p."
  end
  defp move_string(_board, %{piece: :pawn, from: {from_row, from_col, _}, to: {to_row, to_col}, promotion: into, capture: capture}) do
    case capture do
      true -> "#{from_col}#{from_row}-#{from_col}x#{to_col}#{to_row}=#{into}"
      false -> "#{from_col}#{from_row}-#{from_col}#{to_row}=#{into}"
    end
  end
  defp move_string(_board, %{piece: :pawn, from: {from_row, from_col, _}, to: {to_row, to_col, _}, capture: capture}) do
    case capture do
      true -> "#{from_col}#{from_row}-#{from_col}x#{to_col}#{to_row}"
      false -> "#{from_col}#{from_row}-#{from_col}#{to_row}"
    end
  end
  defp move_string(board, %{color: color, piece: piece, from: {from_row, from_col, _}, to: {to_row, to_col, _}, capture: capture}) do
    piece_code = 
    FENParser.reverse_pieces(:white)
    |> Map.get({:white, piece})

    case Chessboard.has_twin_attacker?(board, {to_row, to_col}) do
      true -> "#{from_col}#{from_row}-#{piece_code}#{from_row}"
      false -> "#{from_col}#{from_row}-#{piece_code}"
    end
    <>
    case capture do
      true -> "x#{to_col}#{to_row}"
      false -> "#{to_col}#{to_row}"
    end
  end

  defp check_or_mate(%{mate: true}), do: "#"
  defp check_or_mate(%{check: true}), do: "+"
  defp check_or_mate(_), do: ""
end
