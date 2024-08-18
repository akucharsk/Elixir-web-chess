defmodule Chess.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias Chess.Repo

  alias Chess.Games.Game
  alias Chess.Accounts

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
        create_game(%{atom => user_id})
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
end
