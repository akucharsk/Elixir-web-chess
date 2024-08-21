defmodule Chess.Chessboard do
    @moduledoc """
    The Chessboard.
    """

    @doc """
        Generates a chessboard
    """
    def generate_chessboard() do
        white_pieces = [rook: "WR", knight: "WN", bishop: "WB", queen: "WK", king: "WQ", bishop: "WB", knight: "WN", rook: "WR"]
        black_pieces = [rook: "BR", knight: "BN", bishop: "BB", queen: "BK", king: "BQ", bishop: "BB", knight: "BN", rook: "BR"]

        for col <- 0..7, row <- [0, 1, 6, 7], into: %{} do
            case row do
                0 -> {{row, col}, {:white, Enum.at(white_pieces, col)}}
                1 -> {{row, col}, {:white, {:pawn, "WP"}}}
                6 -> {{row, col}, {:black, {:pawn, "BP"}}}
                7 -> {{row, col}, {:black, Enum.at(black_pieces, col)}}
            end
        end
    end

    @doc """
        Returns the code/image of the piece at a given position
    """
    def piece_repr_at(board, {row, col}) do
        case Map.get(board, {row, col}) do
        nil -> ""
        {_, {_, piece}} -> piece
        end
    end

    @doc """
        Returns the piece at the given position
    """
    def piece_at(board, {row, col}) do
        Map.get(board, {row, col})
    end

    @doc """
        Returns a list of possible moves for a piece at the given position
    """
    def possible_moves(board, {row, col}) do
        board
        |> possible_moves({row, col}, piece_at(board, {row, col}))
    end

    def possible_moves(_board, _pos, nil), do: []

    # PAWNS
    def possible_moves(board, {1, col}, {:white, {:pawn, _}}) do
        [{2, col}, {3, col}]
    end

    def possible_moves(board, {6, col}, {:black, {:pawn, _}}) do
        [{5, col}, {4, col}]
    end

    def possible_moves(board, {row, col}, {color, {:pawn, _}}) do
        if color == :white, do: [{row + 1, col}], else: [{row - 1, col}]
    end

    # ROOKS
    def possible_moves(board, {row, col}, {_, {:rook, _}}) do
        cols = for i <- 0..7, i != row, into: [], do: {i, col}
        rows = for i <- 0..7, i != col, into: [], do: {row, i}
        cols ++ rows
    end

    # KNIGHTS
    def possible_moves(board, {row, col}, {_, {:knight, _}}) do
        moves = [{row + 2, col + 1}, {row + 2, col - 1}, {row - 2, col + 1}, {row - 2, col - 1},
                 {row + 1, col + 2}, {row + 1, col - 2}, {row - 1, col + 2}, {row - 1, col - 2}]
        Enum.filter(moves, fn {r, c} -> r in 0..7 and c in 0..7 end)
    end

    # BISHOPS
    def possible_moves(board, {row, col}, {_, {:bishop, _}}) do
        moves = for i <- 1..7, into: [] do
            [{row + i, col + i}, {row + i, col - i}, {row - i, col + i}, {row - i, col - i}]
        end
        moves
        |> List.flatten
        |> Enum.filter(fn {r, c} -> r in 0..7 and c in 0..7 end)
    end

    # QUEENS
    def possible_moves(board, {row, col}, {color, {:queen, code}}) do
        possible_moves(board, {row, col}, {color, {:rook, code}}) ++ possible_moves(board, {row, col}, {color, {:bishop, code}})
    end

    # KINGS
    def possible_moves(board, {row, col}, {_, {:king, _}}) do
        moves = [{row + 1, col}, {row + 1, col + 1}, {row, col + 1}, {row - 1, col + 1},
                 {row - 1, col}, {row - 1, col - 1}, {row, col - 1}, {row + 1, col - 1}]
        Enum.filter(moves, fn {r, c} -> r in 0..7 and c in 0..7 end)
    end
    
    @doc """
        Moves a piece from one position to another
    """
    def move_piece(board, {from_row, from_col}, {to_row, to_col}) do
        if piece = piece_at(board, {from_row, from_col}) do
            board
            |> Map.delete({from_row, from_col})
            |> Map.put({to_row, to_col}, piece)
        else
            board
        end
    end
end