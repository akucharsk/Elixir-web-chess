defmodule MoveValidator do
    @moduledoc """
        Validates moves of chess pieces or of moves in a given direction.
    """

    alias Chess.Chessboard
    
    @doc """
        Validates the moves of a piece in a straight line from the origin (in one direction).
        Can be diagonal, horizontal or vertical.
    """
    def validate_straight_line(board, moves, {color, {_piece, _tag}}) do
        moves
        |> Enum.reduce({[], :ok}, fn 
            {_row, _col}, {acc, :stop} -> {acc, :stop}
            {row, col}, {acc, :ok} -> 
                case Chessboard.piece_at(board, {row, col}) do
                    nil -> {acc ++ [{row, col}], :ok}
                    {^color, _} -> {acc, :stop}
                    _ -> {acc ++ [{row, col}], :stop}
                end     
            end )
        |> elem(0)
    end
end