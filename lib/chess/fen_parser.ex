defmodule Chess.FENParser do
    @moduledoc """
        This module is responsible for parsing FEN strings to chessboard states, and vice versa.
    """

    @white_pieces %{"K" => {:white, {:king, "white-king"}},
                    "Q" => {:white, {:queen, "white-queen"}},
                    "R" => {:white, {:rook, "white-rook"}},
                    "B" => {:white, {:bishop, "white-bishop"}},
                    "N" => {:white, {:knight, "white-knight"}},
                    "P" => {:white, {:pawn, "white-pawn"}}}
    @white_pieces_reverse for {key, piece} <- @white_pieces, into: %{}, do: {piece, key}
    
    @black_pieces Map.new(@white_pieces, 
                    fn {key, {_, {piece, "white-" <> name}}} -> {String.downcase(key), {:black, {piece, "black-" <> name}}} end)
    @black_pieces_reverse for {key, piece} <- @black_pieces, into: %{}, do: {piece, key}

    @base_fen "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 0"

    def white_pieces(), do: @white_pieces
    def black_pieces(), do: @black_pieces
    def base_fen(), do: @base_fen

    def pieces(:white), do: @white_pieces
    def pieces(:black), do: @black_pieces
    def reverse_pieces(:white), do: @white_pieces_reverse
    def reverse_pieces(:black), do: @black_pieces_reverse

    @doc """
        Generates a chessboard from a FEN string.
    """
    def game_from_fen(fen) do
        case String.split(fen, " ") do
        [board, turn, castling_rights, en_passant, halfmove_clock, fullmove_number] ->

            game_data = 
            %{}
            |> register_board(board)
            |> register_turn(turn)
            |> register_castling_rights(castling_rights)
            |> register_en_passant(en_passant)
            |> register_halfmove_clock(halfmove_clock)
            |> register_fullmoves(fullmove_number)

            case game_data do
                {:ok, board} -> {:ok, board}
                {:error, reason} -> {:error, "Invalid FEN string! Reason: #{reason}"}
            end
        params -> {:error, "Invalid FEN string! Not enough parameters, expected 6, got #{length(params)}"}
        end
    end
    
    def game_from_fen!(fen) do
        case game_from_fen(fen) do
            {:ok, game} -> game
            {:error, reason} -> raise ArgumentError, reason
        end
    end

    # Board registration
    defp register_board(game_data, board) do
        board
        |> String.split("/")
        |> Enum.with_index
        |> Enum.map(fn {rank, idx} -> {rank, 7 - idx} end)
        |> Enum.reduce({:ok, []}, 
            fn 
                {fen_code, rank}, {:ok, acc} -> 
                    case parse_rank({fen_code, rank}) do
                        {:ok, parsed} -> {:ok, [parsed | acc]}
                        {:error, reason} -> {:error, reason}
                    end
                {_, _}, {:error, reason} ->
                    {:error, reason}
            end)
        |> case do
            {:ok, acc} -> {:ok, Map.put(game_data, :board, acc |> List.flatten |> Enum.into(%{}))}
            {:error, reason} -> {:error, reason}
        end
    end

    defp parse_rank({fen_code, rank}) do
        fen_code
        |> String.graphemes
        |> Enum.reduce({rank, 0, []}, &parse_fen_code/2)
        |> case do
            {^rank, 8, acc} -> {:ok, acc}
            {rank, _file, _} -> {:error, "Invalid FEN code: Rank #{rank} with too few files"}
            {:error, reason} -> {:error, "Invalid FEN code: #{reason}"}
        end
    end
    
    defp parse_fen_code(_char, {:error, reason}), do: {:error, reason}
    defp parse_fen_code(_char, {rank, _file, _acc}) when rank > 7, do: {:error, "Invalid FEN code: rank #{rank} is out of bounds"}
    defp parse_fen_code(_char, {rank, file, _acc}) when file > 7, do: {:error, "Invalid FEN code: rank #{rank} with too many files"}
    defp parse_fen_code(char, {rank, file, acc}) when char in ["P", "Q", "K", "R", "B", "N"] do
        {rank, file + 1, [{{rank, file}, Map.get(@white_pieces, char)} | acc]}
    end
    defp parse_fen_code(char, {rank, file, acc}) when char in ["p", "q", "k", "r", "b", "n"] do
        {rank, file + 1, [{{rank, file}, Map.get(@black_pieces, char)} | acc]}
    end
    defp parse_fen_code(char, {rank, file, acc}) do
        case Regex.match?(~r/\d/, char) do
            true -> {rank, file + String.to_integer(char), acc}
            false -> {:error, "Invalid FEN code: #{char} isn't a valid FEN chessboard code"}
        end
    end

    # Turn registration
    defp register_turn({:ok, game_data}, "w"), do: {:ok, Map.put(game_data, :turn, :white)}
    defp register_turn({:ok, game_data}, "b"), do: {:ok, Map.put(game_data, :turn, :black)}
    defp register_turn({:error, reason}, _turn), do: {:error, reason}
    defp register_turn(_, _), do: {:error, "Invalid turn"}

    # Castling rights registration
    defp register_castling_rights({:ok, game_data}, "-") do
        {:ok,
            game_data
            |> Map.put(:castling_rights, %{white: %{long: false, short: false}, black: %{long: false, short: false}})
        }
    end
    defp register_castling_rights({:ok, game_data}, castling_rights) do
        castling_rights
        |> String.graphemes
        |> Enum.reduce({:ok, %{white: %{long: false, short: false}, black: %{long: false, short: false}}},
            fn
                "K", {:ok, map} -> {:ok, %{map | white: %{map.white | short: true}}}
                "Q", {:ok, map} -> {:ok, %{map | white: %{map.white | long: true}}}
                "k", {:ok, map} -> {:ok, %{map | black: %{map.black | short: true}}}
                "q", {:ok, map} -> {:ok, %{map | black: %{map.black | long: true}}}
                char, {:ok, _map} -> {:error, "Invalid FEN code: no such castling right: #{char}"}
                _, {:error, reason} -> {:error, reason} 
            end)
        |> case do
            {:ok, map} -> {:ok, Map.put(game_data, :castling_rights, map)}
            {:error, reason} -> {:error, reason}
        end
    end
    defp register_castling_rights({:error, reason}, _castling_rights), do: {:error, reason}

    # En passant registration
    defp get_field(square), do: (square |> String.downcase |> String.to_charlist |> List.first) - ?a

    defp register_en_passant({:ok, game_data}, "-"), do: {:ok, Map.put(game_data, :en_passant, nil)}
    defp register_en_passant({:ok, %{board: board, turn: :white, castling_rights: _rights}} = game_data, en_passant) do
        if Regex.match?(~r/[A-Ha-h]6/, en_passant) do
            field = get_field(en_passant)

            if Enum.any?(board, fn {{4, ^field}, {:black, {:pawn, _}}} -> true; _ -> false end) do
                {:ok, Map.put(game_data, :en_passant, {5, field})}
            else
                {:error, "Invalid FEN code: Impossible to execute en-passant on square #{en_passant}"}
            end
        else
            {:error, "Invalid FEN code: Impossible to execute en-passant on square #{en_passant}"}
        end
    end
    defp register_en_passant({:ok, %{board: board, turn: :black, castling_rights: _rights}} = game_data, en_passant) do
        if Regex.match?(~r/[A-Ha-h]3/, en_passant) do
            field = get_field(en_passant)

            if Enum.any?(board, fn {{3, ^field}, {:white, {:pawn, _}}} -> true; _ -> false end) do
                {:ok, Map.put(game_data, :en_passant, {2, field})}
            else
                {:error, "Invalid FEN code: Impossible to execute en-passant on square #{en_passant}"}
            end
        else
            {:error, "Invalid FEN code: Impossible to execute en-passant on square #{en_passant}"}
        end
    end
    defp register_en_passant({:ok, _game_data}, en_passant), do: {:error, "Invalid FEN code: Impossible to execute en-passant on square #{en_passant}"}
    defp register_en_passant({:error, reason}, _), do: {:error, reason}

    # Halfmove clock registration
    defp register_halfmove_clock({:ok, game_data}, halfmoves) do
        case Regex.match?(~r/^\d+$/, halfmoves) do
            true -> {:ok, game_data |> Map.put(:halfmoves, min(String.to_integer(halfmoves), 100))}
            false ->{:error, "Invalid FEN code: Invalid halfmove clock input (#{halfmoves})"}
        end
    end
    defp register_halfmove_clock({:error, reason}, _), do: {:error, reason}

    # Fullmove registration
    defp register_fullmoves({:ok, game_data}, fullmoves) do
        case Regex.match?(~r/^\d+$/, fullmoves) do
            true -> {:ok, game_data |> Map.put(:fullmoves, String.to_integer(fullmoves))}
            false -> {:error, "Invalid FEN code: Invalid fullmoves (#{fullmoves})"}
        end
    end
    defp register_fullmoves({:error, reason}, _), do: {:error, reason}

    @doc """
        Generates a FEN string from a chessboard.
    """
    def fen_from_game!(%{board: board, turn: turn, castling_rights: castling_rights, en_passant: en_passant, halfmoves: halfmoves, fullmoves: fullmoves}) do
        board
        |> expand_board
        |> Enum.reduce([], &fen_from_rank/2)
        |> Enum.intersperse("/")
        |> Enum.into("")
        |> Kernel.<>(" #{turn_to_fen(turn)} #{castling_rights_to_fen(castling_rights)} #{en_passant_to_fen(en_passant)} #{halfmoves} #{fullmoves}")
    end

    defp expand_board(board) do
        for rank <- 0..7 do
            for file <- 0..7 do
                {{rank, file}, Map.get(board, {rank, file})}
            end
        end
    end

    defp fen_from_rank(rank, acc) do
        reduced_rank =
        rank
        |> Enum.reduce({[], 0},
            fn
                {_, nil}, {inner_acc, val} -> {inner_acc, val + 1}
                {_, {color, _} = piece}, {inner_acc, 0} -> {[reverse_pieces(color)[piece] | inner_acc], 0}
                {_, {color, _} = piece}, {inner_acc, val} -> {["#{val}#{reverse_pieces(color)[piece]}" | inner_acc], 0}
            end)
        |> case do
                {[], 8} -> ["8"]
                {inner_acc, 0} -> inner_acc
                {inner_acc, val} -> ["#{val}" | inner_acc]
            end
        |> Enum.reverse
        |> Enum.join("")

        [reduced_rank | acc]
    end

    defp turn_to_fen(:white), do: "w"
    defp turn_to_fen(:black), do: "b"
    defp turn_to_fen(_), do: raise ArgumentError, "Invalid turn"

    defp castling_rights_to_fen(%{white: %{long: white_long, short: white_short}, black: %{long: black_long, short: black_short}}) do
        ["q", "k", "Q", "K"]
        |> Enum.reduce([], 
            fn
                "K", acc -> if white_short, do: ["K" | acc], else: acc
                "Q", acc -> if white_long, do: ["Q" | acc], else: acc
                "k", acc -> if black_short, do: ["k" | acc], else: acc
                "q", acc -> if black_long, do: ["q" | acc], else: acc
            end)
        |> Enum.into("")
        |> case do
            "" -> "-"
            str -> str
        end
    end
    defp castling_rights_to_fen(_), do: raise ArgumentError, "Invalid castling rights"
    
    defp en_passant_to_fen({rank, file}), do: "#{<<?a + file>>}#{rank}"
    defp en_passant_to_fen(nil), do: "-"
    defp en_passant_to_fen(_), do: raise ArgumentError, "Invalid en passant"
end