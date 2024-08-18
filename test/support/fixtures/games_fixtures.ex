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
end
