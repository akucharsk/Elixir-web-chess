defmodule Chess.GamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Chess.Games` context.
  """

  @doc """
  Generate a game.
  """
  def game_fixture(attrs \\ %{}) do
    {:ok, game} =
      attrs
      |> Enum.into(%{
        fen: "some fen",
        pen: "some pen",
        result: 42,
        score: 42
      })
      |> Chess.Games.create_game()

    game
  end

  @doc """
  Generate a pen.
  """
  def pen_fixture(attrs \\ %{}) do
    {:ok, pen} =
      attrs
      |> Enum.into(%{
        black_move: "some black_move",
        move: 42,
        white_move: "some white_move"
      })
      |> Chess.Games.create_pen()

    pen
  end

  @doc """
  Generate a move.
  """
  def move_fixture(attrs \\ %{}) do
    {:ok, move} =
      attrs
      |> Enum.into(%{
        black_move: "some black_move",
        move: 42,
        white_move: "some white_move"
      })
      |> Chess.Games.create_move()

    move
  end
end
