defmodule Chess.Chessboard do
    @moduledoc """
    The Chessboard.
    """

    alias Chess.FENParser

    @piece_values %{pawn: 1, knight: 3, bishop: 3, rook: 5, queen: 9, king: :inf}

    def piece_value(piece), do: Map.get(@piece_values, 0, piece)

    def opposite_color(:white), do: :black
    def opposite_color(:black), do: :white

    @doc """
        Generates a chessboard
    """
    def generate_chessboard() do
        FENParser.base_fen
        |> FENParser.game_from_fen!
        |> Map.get(:board)
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

    def piece_at(board, {row, col, _spec}) do
        piece_at(board, {row, col})
    end

    @doc """
        Returns a list of possible moves for a piece at the given position
    """
    def possible_moves(board, {row, col}) do
        board
        |> possible_moves({row, col}, piece_at(board, {row, col}))
    end

    # PAWNS
    def possible_moves(board, {row, col}, {color, {:pawn, _}} = piece) do
        next_row = if color == :white, do: row + 1, else: row - 1
        case piece_at(board, {next_row, col}) do
            nil -> [{next_row, col, nil}] ++ extra_square(board, {row, col}, color)
            _ -> []
        end
        ++ pawn_takes(board, {row, col}, piece)
    end

    defp extra_square(board, {1, col}, :white) do
        case piece_at(board, {3, col}) do
            nil -> [{3, col, nil}]
            _ -> []
        end
    end
    defp extra_square(board, {6, col}, :black) do
        case piece_at(board, {4, col}) do
            nil -> [{4, col, nil}]
            _ -> []
        end
    end
    defp extra_square(_board, _pos, _color), do: []

    defp pawn_takes(board, {row, col}, {color, {:pawn, _}}) do
        row = if color == :white, do: row + 1, else: row - 1
        [{row, col + 1, :take}, {row, col - 1, :take}]
        |> Enum.filter(fn {r, c, _action} -> 
            r in 0..7 and c in 0..7 and
            case piece_at(board, {r, c}) do
                nil -> false
                {^color, _} -> false
                _ -> true
            end
        end)
    end
    defp pawn_takes(_board, _pos, _piece), do: []

    # ROOKS
    def possible_moves(board, {row, col}, {_color, {:rook, _}} = piece) do
        left = for i <- col..0, i != col, into: [], do: {row, i, nil}
        right = for i <- col..7, i != col, into: [], do: {row, i, nil}
        up = for i <- row..7, i != row, into: [], do: {i, col, nil}
        down = for i <- row..0, i != row, into: [], do: {i, col, nil}
        
        validate_straight_line(board, left, piece) ++
        validate_straight_line(board, right, piece) ++
        validate_straight_line(board, up, piece) ++
        validate_straight_line(board, down, piece)
    end

    # KNIGHTS
    def possible_moves(board, {row, col}, {_color, {:knight, _}} = piece) do
        [{row + 2, col + 1, nil}, {row + 2, col - 1, nil}, {row - 2, col + 1, nil}, {row - 2, col - 1, nil},
        {row + 1, col + 2, nil}, {row + 1, col - 2, nil}, {row - 1, col + 2, nil}, {row - 1, col - 2, nil}]
        |> validate_moves(board, piece)
    end

    # BISHOPS
    def possible_moves(board, {row, col}, {_color, {:bishop, _}} = piece) do
        north_east = for i <- 0..min(7 - row, 7 - col), i > 0, into: [], do: {row + i, col + i, nil}
        north_west = for i <- 0..min(7 - row, col), i > 0, into: [], do: {row + i, col - i, nil}
        south_east = for i <- 0..min(row, 7 - col), i > 0, into: [], do: {row - i, col + i, nil}
        south_west = for i <- 0..min(row, col), i > 0, into: [], do: {row - i, col - i, nil}

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
    def possible_moves(board, {row, col}, {_color, {:king, _}} = piece) do
        [{row + 1, col, nil}, {row + 1, col + 1, nil}, {row, col + 1, nil}, {row - 1, col + 1, nil},
        {row - 1, col, nil}, {row - 1, col - 1, nil}, {row, col - 1, nil}, {row + 1, col - 1, nil}]
        |> validate_moves(board, piece)
    end

    def possible_moves(_board, _pos, nil), do: []
    
    @doc """
        Moves a piece from one position to another, returns the updated board.
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

    def move_piece(board, {from_row, from_col, _from_spec}, {to_row, to_col, to_spec}) do
        case to_spec do
            "en_passant" ->
                board
                |> Map.delete({from_row, to_col})

            "long_castling" ->
                board
                |> Map.put({to_row, 3}, piece_at(board, {to_row, 0}))
                |> Map.delete({from_row, 0})

            "short_castling" ->
                board
                |> Map.put({to_row, 5}, piece_at(board, {to_row, 7}))
                |> Map.delete({from_row, 7})

            _ -> board
        end
        |> move_piece({from_row, from_col}, {to_row, to_col})
    end

    # for debugging purposes
    def move_piece(board, from, to) do
        IO.inspect({from, to}, label: "Invalid move")
        board
    end

    @doc """
        Validates the moves of a piece in a straight line from the origin (in one direction).
        Can be diagonal, horizontal or vertical.
    """
    def validate_straight_line(board, moves, {color, {_piece, _tag}}) do
        moves
        |> Enum.reduce({[], :ok}, fn 
            {_row, _col, _action}, {acc, :stop} -> {acc, :stop}
            {row, col, nil}, {acc, :ok} -> 
                case piece_at(board, {row, col}) do
                    nil -> {acc ++ [{row, col, nil}], :ok}
                    {^color, _} -> {acc, :stop}
                    _ -> {acc ++ [{row, col, nil}], :stop}
                end     
            end)
        |> elem(0)
    end

    @doc """
        Validates the moves of a piece. Moves can't be in a diagonal, horizontal or vertical line.
    """
    def validate_moves(moves, board, {color, {_piece, _tag}}) do
        moves
        |> Enum.filter(fn {r, c, nil} -> r in 0..7 and c in 0..7 end)
        |> Enum.map(fn {r, c, nil} -> 
            case piece_at(board, {r, c}) do
                nil -> {r, c, nil}
                {^color, _} -> :invalid
                _ -> {r, c, nil}
            end
        end)
        |> Enum.filter(&(&1 != :invalid))
    end

    @doc """
        Checks if a given position is attacked by a piece of a given color.
    """
    def is_attacked?(board, {row, col}, color) do
        board
        |> Enum.filter(fn {{_, _}, {^color, _}} -> true; _ -> false end)
        |> Enum.flat_map(fn {{r, c}, _} = pc -> possible_moves(board, {r, c}) ++ pawn_takes(board, {r, c}, pc) end)
        |> Enum.any?(fn {r, c, _spec} -> {r, c} == {row, col} end)
    end

    @doc """
        Scans if there are any checks on the board for a given color.
    """

    def scan_checks(board, :white) do
        white_king_pos = Enum.find(board, fn {{_, _}, {:white, {:king, _}}} -> true; _ -> false end) |> elem(0)
        
        is_attacked?(board, white_king_pos, :black)
    end

    def scan_checks(board, :black) do
        black_king_pos = Enum.find(board, fn {{_, _}, {:black, {:king, _}}} -> true; _ -> false end) |> elem(0)
        
        is_attacked?(board, black_king_pos, :white)
    end

    @doc """
        Checks if there are any legal moves for a given player
    """
    def cannot_move?(board, color) do
        board
        |> Enum.filter(fn {{_, _}, {^color, _}} -> true; _ -> false end)
        |> Enum.flat_map(fn {{r, c}, piece} -> possible_moves(board, {r, c}) |> filter_checks(board, {r, c}, piece) end)
        |> Enum.empty?
    end

    @doc """
        Filters out all moves that would result in a check for the player moving the piece.
    """
    def filter_checks(moves, board, {row, col}, {color, {_piece, _tag}}) do
        moves
        |> Enum.filter(fn {r, c, _spec} ->
            board
            |> move_piece({row, col}, {r, c})
            |> scan_checks(color) == false
        end)
    end

    defp check_en_passant({4, _col}, {:white, {:pawn, _}}, %{from: {6, last_col, _}, to: {4, last_col, _}}) do
        [{5, last_col, :en_passant}]
    end

    defp check_en_passant({3, _col}, {:black, {:pawn, _}}, %{from: {1, last_col, _}, to: {3, last_col, _}}) do
        [{2, last_col, :en_passant}]
    end

    defp check_en_passant(_pos, _piece, _last_move), do: []

    @doc """
        Checks en passant, and appends it to the current possible moves of a given piece
    """
    def append_en_passant(moves, {_row, _col} = pos, {_color, {_piece, _}} = piece, last_move) do
        moves ++ check_en_passant(pos, piece, last_move)
    end

    def append_castling(moves, board, %{long: long_privilege?, short: short_privilege?}, {color, {:king, _}}) do
        moves
        ++
        case long_privilege? do
            true -> check_long_castling(board, color)
            false -> []
        end
        ++
        case short_privilege? do
            true -> check_short_castling(board, color)
            false -> []
        end
    end

    def append_castling(moves, _board, _privileges, _piece), do: moves

    defp check_long_castling(board, color) do
        row = if color == :white, do: 0, else: 7
        king_pos = {row, 4}
        rook_pos = {row, 0}

        opposite = opposite_color(color)

        if is_attacked?(board, king_pos, opposite) or
            is_attacked?(board, rook_pos, opposite) or
            Enum.any?(1..3, fn i -> not is_nil(piece_at(board, {row, i})) or is_attacked?(board, {row, i}, opposite) end) do
                []
            else
                [{row, 2, :long_castling}]
            end
    end

    defp check_short_castling(board, color) do
        row = if color == :white, do: 0, else: 7
        king_pos = {row, 4}
        rook_pos = {row, 7}

        opposite = opposite_color(color)

        if is_attacked?(board, king_pos, opposite) or
            is_attacked?(board, rook_pos, opposite) or
            Enum.any?(5..6, fn i -> not is_nil(piece_at(board, {row, i})) or is_attacked?(board, {row, i}, opposite) end) do
                []
            else
                [{row, 6, :short_castling}]
            end
    end

    @doc """
        Returns the castling privileges for a given color after a move.
        Syntax:
        update_castling_privileges(current_privileges, {from_row, from_col}, {color, {piece, _tag}})
    """
    def update_castling_privileges(privileges, {from_row, from_col, _spec}, {_color, {_piece, _tag}} = piece) do
        update_castling_privileges(privileges, {from_row, from_col}, piece)
    end

    def update_castling_privileges(privileges, {0, 0}, {:white, {:rook, _}}), do: %{privileges | white: %{privileges.white | long: false}}
    def update_castling_privileges(privileges, {0, 7}, {:white, {:rook, _}}), do: %{privileges | white: %{privileges.white | short: false}}
    def update_castling_privileges(privileges, {0, 4}, {:white, {:king, _}}), do: %{privileges | white: %{long: false, short: false}}
    def update_castling_privileges(privileges, {7, 0}, {:black, {:rook, _}}), do: %{privileges | black: %{privileges.black | long: false}}
    def update_castling_privileges(privileges, {7, 7}, {:black, {:rook, _}}), do: %{privileges | black: %{privileges.black | short: false}}
    def update_castling_privileges(privileges, {7, 4}, {:black, {:king, _}}), do: %{privileges | black: %{long: false, short: false}}
    
    def update_castling_privileges(privileges, _pos, _piece), do: privileges

    @doc """
        This function is meant to be called BEFORE a move is made. It returns a boolean indicating
        if the square where a piece wants to move is also in the list of possible moves of
        a different piece of the same color, and type.
        
        ## Examples
        
        Let's say we have rooks on their home squares, and both on the A file and the 1st rank thery are no other pieces.
        The moved piece is the A1 ({0, 0}) rook.

        iex> has_twin_attacker?(board, {0, 4} = {to_rank, to_file})
        true
        # True is returned because the white H1 rook can also move to {0, 4} meaning E1

        iex> has_twin_attacker?(board, {4, 0} = {to_rank, to_file})
        false
        # False is returned because the white H1 rook can't move to {4, 0} meaning A5. The black rook on A8 can, though and
        # it's accounted for.

        The same applies to the other pieces, like knights: if we have white knights on B1 ({0, 1}) and E4 ({3, 4})
        Let's say the B1 knight is making a move.

        iex> has_twin_attacker?(board, {2, 2} = {to_rank, to_file})
        true

        iex> has_twin_attacker?(board, {2, 0} = {to_rank, to_file})
        false
    """
    def has_twin_attacker?(board, {from_rank, from_file}, {to_rank, to_file}) do
        {color, {piece, _}} = piece_at(board, {from_rank, from_file})

        board
        |> Enum.filter(
            fn 
                {{^from_rank, ^from_file}, _} -> false
                {{_, _}, {^color, {^piece, _}}} -> true
                _ -> false
            end
        )
        |> Enum.any?(
            fn 
                {{rank, file}, {^color, {^piece, _}}}-> {to_rank, to_file, nil} in possible_moves(board, {rank, file})
            end)
    end
    def has_twin_attacker?(board, {from_rank, from_file, _}, {to_rank, to_file, _}), do: has_twin_attacker?(board, {from_rank, from_file}, {to_rank, to_file})

    @doc """
        Promotes a pawn to the piece specified by the code (Q, R, B, N)
    """
    def promote_pawn(board, _, nil), do: board
    def promote_pawn(board, {row, col, _}, code), do: promote_pawn(board, {row, col}, code)
    def promote_pawn(board, {row, col}, code) do
        {color, _} = piece_at(board, {row, col})
        {:white, {piece, "white" <> piece_str}} = FENParser.white_pieces[code]
        board
        |> Map.put({row, col}, {color, {piece, Atom.to_string(color) <> piece_str}})
    end
end