defmodule Chess.GamesTest do
  use Chess.DataCase

  alias Chess.Games

  describe "games" do
    alias Chess.Games.Game

    import Chess.GamesFixtures

    @invalid_attrs %{fen: nil, pen: nil, result: nil, score: nil}

    test "list_games/0 returns all games" do
      game = game_fixture()
      assert Games.list_games() == [game]
    end

    test "get_game!/1 returns the game with given id" do
      game = game_fixture()
      assert Games.get_game!(game.id) == game
    end

    test "create_game/1 with valid data creates a game" do
      valid_attrs = %{fen: "some fen", pen: "some pen", result: 42, score: 42}

      assert {:ok, %Game{} = game} = Games.create_game(valid_attrs)
      assert game.fen == "some fen"
      assert game.pen == "some pen"
      assert game.result == 42
      assert game.score == 42
    end

    test "create_game/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Games.create_game(@invalid_attrs)
    end

    test "update_game/2 with valid data updates the game" do
      game = game_fixture()
      update_attrs = %{fen: "some updated fen", pen: "some updated pen", result: 43, score: 43}

      assert {:ok, %Game{} = game} = Games.update_game(game, update_attrs)
      assert game.fen == "some updated fen"
      assert game.pen == "some updated pen"
      assert game.result == 43
      assert game.score == 43
    end

    test "update_game/2 with invalid data returns error changeset" do
      game = game_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.update_game(game, @invalid_attrs)
      assert game == Games.get_game!(game.id)
    end

    test "delete_game/1 deletes the game" do
      game = game_fixture()
      assert {:ok, %Game{}} = Games.delete_game(game)
      assert_raise Ecto.NoResultsError, fn -> Games.get_game!(game.id) end
    end

    test "change_game/1 returns a game changeset" do
      game = game_fixture()
      assert %Ecto.Changeset{} = Games.change_game(game)
    end
  end
end
