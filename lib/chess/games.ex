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

  @doc """
    Returns the user who won the game.
  """
  def get_winner(%Game{} = game) do
    case game.winner_id do
      nil -> nil
      winner_id -> Accounts.get_user!(winner_id)
    end
  end


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
  def register_move(board, last_move, fullmoves, game_id)
    do
      last_move
      |> Map.put(:move_number, fullmoves)
      |> Map.put(:game_id, game_id)
      |> Map.put(:move_code, encode_move(last_move))
      |> Map.update!(:from, &encode_position/1)
      |> Map.update!(:to, &encode_position/1)
      |> Map.update!(:piece, fn piece -> FENParser.reverse_pieces(:white)[{:white, piece}] end)
      |> Map.update!(:color, &Atom.to_string/1)
      |> create_move
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

    @doc """
      Returns the human readable representation of a square. rank and file are 0-indexed.

      ## Examples

      iex> encode_position({0, 0})
      "a1"

      iex> encode_position({7, 7})
      "h8"
    """
    def encode_position({rank, file}) when rank in 0..7 and file in 0..7, do: "#{<<?a + file>>}#{rank + 1}"
    def encode_position({rank, file, _}), do: encode_position({rank, file})
    def encode_position(_), do: nil

    def encode_move(%{mate: true} = last_move), do: encode_move(%{last_move | mate: false, check: false}) <> "#"
    def encode_move(%{check: true} = last_move), do: encode_move(%{last_move | check: false}) <> "+"
    def encode_move(%{piece: :king, to: {_, _, "short_castling"}}), do: "O-O"
    def encode_move(%{piece: :king, to: {_, _, "long_castling"}}), do: "O-O-O"
    def encode_move(%{piece: :pawn, promotion: promo} = last_move) when not is_nil(promo), do: encode_move(%{last_move | promotion: nil}) <> "=#{promo}"
    def encode_move(%{piece: :pawn, to: {to_rank, to_file, "en_passant"}} = last_move), do: encode_move(%{last_move | to: {to_rank, to_file, nil}}) <> "e.p."
    def encode_move(%{piece: :pawn, capture: nil, to: {to_rank, to_file, _}}), do: encode_position({to_rank, to_file})
    def encode_move(%{piece: :pawn, from: {_, from_file, _}, to: {to_rank, to_file, _}}), do: "#{<<?a + from_file>>}x" <> encode_position({to_rank, to_file})
    def encode_move(%{piece: piece, capture: capture, twin: false, to: {to_rank, to_file, _}}) do
      "#{FENParser.reverse_pieces(:white)[{:white, piece}]}"
      <> (if capture, do: "x", else: "")
      <> encode_position({to_rank, to_file})
    end
    def encode_move(%{piece: piece, capture: capture, twin: true, from: {_, from_file, _}, to: {to_rank, to_file, _}}) do
      "#{FENParser.reverse_pieces(:white)[{:white, piece}]}#{<<?a + from_file>>}"
      <> (if capture, do: "x", else: "")
      <> encode_position({to_rank, to_file})
    end

    @doc """
      Assigns a winner to a game. The result can be :white, :black or nil.
    """
    def assign_winner(%Game{} = game, :white), do: update_game(game, %{winner_id: game.white_id, white_score: 1.0, black_score: 0.0})
    def assign_winner(%Game{} = game, :black), do: update_game(game, %{winner_id: game.black_id, white_score: 0.0, black_score: 1.0})
    def assign_winner(%Game{} = game, nil), do: update_game(game, %{winner_id: nil, white_score: 0.5, black_score: 0.5})

    @doc """
      Fulfills a resignation request. Calls the above assign_winner function for the opposite color.
    """
    def resign(%Game{} = game, :white), do: assign_winner(game, :black)
    def resign(%Game{} = game, :black), do: assign_winner(game, :white)

    @doc """
      Returns the opponent of a player in a game.
    """
    def opponent(%Game{white_id: white, black_id: black}, white), do: Accounts.get_user!(black)
    def opponent(%Game{white_id: white, black_id: black}, black), do: Accounts.get_user!(white)

    @doc """
      Returns true if the player is about to promote a pawn.
    """
    def promotion?(board, {6, _, _} = from, {7, _, _} = _to) do
      case Chessboard.piece_at(board, from) do
        {:white, {:pawn, _}} -> true
        _ -> false
      end
    end
    def promotion?(board, {1, _, _} = from, {0, _, _} = _to) do
      case Chessboard.piece_at(board, from) do
        {:black, {:pawn, _}} -> true
        _ -> false
      end
    end
    def promotion?(board, {rank, file} = _from, {_, _, _} = to), do: promotion?(board, {rank, file, nil}, to)
    def promotion?(_, _, _), do: false
end
