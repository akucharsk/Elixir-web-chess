defmodule Chess.Chessboard do
    @moduledoc """
    The Chessboard.
    """

    @doc """
        Generates a chessboard
    """
    def generate_chessboard() do
        white_pieces = [rook: "white-rook", knight: "white-knight", bishop: "white-bishop", king: "white-king",
         queen: "white-queen", bishop: "white-bishop", knight: "white-knight", rook: "white-rook"]
        black_pieces = Enum.map(white_pieces, fn {piece, code} -> {piece, String.replace(code, "white", "black")} end)

        for col <- 0..7, row <- [0, 1, 6, 7], into: %{} do
            case row do
                0 -> {{row, col}, {:white, Enum.at(white_pieces, col)}}
                1 -> {{row, col}, {:white, {:pawn, "white-pawn"}}}
                6 -> {{row, col}, {:black, {:pawn, "black-pawn"}}}
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
    def possible_moves(board, {1, col}, {:white, {:pawn, _}} = piece) do
        case piece_at(board, {2, col}) do
            nil -> [{2, col}] ++ possible_moves(board, {2, col}, piece) -- pawn_takes(board, {2, col}, piece)
            _ -> []
        end
    end

    def possible_moves(board, {6, col}, {:black, {:pawn, _}} = piece) do
        case piece_at(board, {5, col}) do
            nil -> [{5, col}] ++ possible_moves(board, {5, col}, piece) -- pawn_takes(board, {5, col}, piece)
            _ -> []
        end
    end

    def possible_moves(board, {row, col}, {color, {:pawn, _}} = piece) do
        next_row = if color == :white, do: row + 1, else: row - 1
        case piece_at(board, {next_row, col}) do
            nil -> [{next_row, col}]
            _ -> []
        end
        ++ pawn_takes(board, {row, col}, piece)
    end

    defp pawn_takes(board, {row, col}, {color, {:pawn, _}}) do
        row = if color == :white, do: row + 1, else: row - 1
        [{row, col + 1}, {row, col - 1}]
        |> Enum.filter(fn {r, c} -> 
            r in 0..7 and c in 0..7 and
            case piece_at(board, {r, c}) do
                nil -> false
                {^color, _} -> false
                _ -> true
            end
        end)
    end

    # ROOKS
    def possible_moves(board, {row, col}, {color, {:rook, _}} = piece) do
        left = for i <- col..0, i != col, into: [], do: {row, i}
        right = for i <- col..7, i != col, into: [], do: {row, i}
        up = for i <- row..7, i != row, into: [], do: {i, col}
        down = for i <- row..0, i != row, into: [], do: {i, col}
        
        validate_straight_line(board, left, piece) ++
        validate_straight_line(board, right, piece) ++
        validate_straight_line(board, up, piece) ++
        validate_straight_line(board, down, piece)
    end

    # KNIGHTS
    def possible_moves(board, {row, col}, {color, {:knight, _}} = piece) do
        [{row + 2, col + 1}, {row + 2, col - 1}, {row - 2, col + 1}, {row - 2, col - 1},
        {row + 1, col + 2}, {row + 1, col - 2}, {row - 1, col + 2}, {row - 1, col - 2}]
        |> validate_moves(board, piece)
    end

    # BISHOPS
    def possible_moves(board, {row, col}, {color, {:bishop, _}} = piece) do
        north_east = for i <- 0..min(7 - row, 7 - col), i > 0, into: [], do: {row + i, col + i}
        north_west = for i <- 0..min(7 - row, col), i > 0, into: [], do: {row + i, col - i}
        south_east = for i <- 0..min(row, 7 - col), i > 0, into: [], do: {row - i, col + i}
        south_west = for i <- 0..min(row, col), i > 0, into: [], do: {row - i, col - i}

        validate_straight_line(board, north_east, piece) ++
        validate_straight_line(board, north_west, piece) ++
        validate_straight_line(board, south_east, piece) ++
        validate_straight_line(board, south_west, piece)
    end

    # QUEENS
    def possible_moves(board, {row, col}, {color, {:queen, code}}) do
        possible_moves(board, {row, col}, {color, {:rook, code}}) ++ possible_moves(board, {row, col}, {color, {:bishop, code}})
    end

    # KINGS
    def possible_moves(board, {row, col}, {color, {:king, _}} = piece) do
        [{row + 1, col}, {row + 1, col + 1}, {row, col + 1}, {row - 1, col + 1},
        {row - 1, col}, {row - 1, col - 1}, {row, col - 1}, {row + 1, col - 1}]
        |> validate_moves(board, piece)
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

    @doc """
        Validates the moves of a piece in a straight line from the origin (in one direction).
        Can be diagonal, horizontal or vertical.
    """
    def validate_straight_line(board, moves, {color, {_piece, _tag}}) do
        moves
        |> Enum.reduce({[], :ok}, fn 
            {_row, _col}, {acc, :stop} -> {acc, :stop}
            {row, col}, {acc, :ok} -> 
                case piece_at(board, {row, col}) do
                    nil -> {acc ++ [{row, col}], :ok}
                    {^color, _} -> {acc, :stop}
                    _ -> {acc ++ [{row, col}], :stop}
                end     
            end)
        |> elem(0)
    end

    @doc """
        Validates the moves of a piece. Moves can't be in a diagonal, horizontal or vertical line.
    """
    def validate_moves(moves, board, {color, {_piece, _tag}}) do
        moves
        |> Enum.filter(fn {r, c} -> r in 0..7 and c in 0..7 end)
        |> Enum.filter(fn {r, c} -> 
            case piece_at(board, {r, c}) do
                nil -> true
                {^color, _} -> false
                _ -> true
            end
        end)
    end

    @doc """
        Scans if there are any checks on the board, returns :white if the white king is checked,
        :black if the black king is checked, nil if there are no checks, and {:error, message} when both kings are checked.
        Such a situation should never happen.
    """
    def scan_checks(board) do
        white_king_pos = Enum.find(board, fn {{_, _}, {:white, {:king, _}}} -> true; _ -> false end) |> elem(0)
        black_king_pos = Enum.find(board, fn {{_, _}, {:black, {:king, _}}} -> true; _ -> false end) |> elem(0)

        case {scan_checks(board, :white), scan_checks(board, :black)} do
            {true, true} -> {:error, "Both kings are checked"}
            {true, _} -> :white
            {_, true} -> :black
            _ -> nil
        end
    end

    defp scan_checks(board, :white) do
        white_king_pos = Enum.find(board, fn {{_, _}, {:white, {:king, _}}} -> true; _ -> false end) |> elem(0)
        black_pieces = 
        board
        |> Enum.filter(fn {{_, _}, {:black, _}} -> true; _ -> false end)
        |> Enum.map(fn {{row, col}, _} -> {row, col} end)
        |> Enum.flat_map(fn pos -> possible_moves(board, pos) end)

        Enum.any?(black_pieces, fn pos -> pos == white_king_pos end)
    end

    defp scan_checks(board, :black) do
        black_king_pos = Enum.find(board, fn {{_, _}, {:black, {:king, _}}} -> true; _ -> false end) |> elem(0)
        white_pieces =
        board
        |> Enum.filter(fn {{_, _}, {:white, _}} -> true; _ -> false end)
        |> Enum.map(fn {{row, col}, _} -> {row, col} end)
        |> Enum.flat_map(fn pos -> possible_moves(board, pos) end)

        Enum.any?(white_pieces, fn pos -> pos == black_king_pos end)
    end

    @doc """
        Filters out all moves that would result in a check.
    """
    def filter_checks(moves, board, {row, col}, {color, {_piece, _tag}} = piece) do
        moves
        |> Enum.filter(fn {r, c} ->
            board
            |> move_piece({row, col}, {r, c})
            |> scan_checks(color) == false
        end)
    end
end