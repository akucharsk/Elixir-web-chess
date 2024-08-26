defmodule ChessWeb.GameLive.Show do
  use ChessWeb, :live_view

  alias Chess.Games
  alias Chess.Accounts
  alias Chess.Chessboard
  alias Chess.FENParser

  alias ChessWeb.Endpoint

  alias Phoenix.Socket.Broadcast

  @impl true
  def mount(%{"id" => id}, session, socket) do
    user = Accounts.get_user_by_session_token(session["user_token"])
    Endpoint.subscribe("room:#{id}")
    {:ok, 
      socket
      |> assign(:current_user, user)
      |> assign(:live_action, :show)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    game = Games.get_game!(id)

    white = if game.white_id, do: Accounts.get_user!(game.white_id).username, else: nil
    black = if game.black_id, do: Accounts.get_user!(game.black_id).username, else: nil
    color = if socket.assigns.current_user.id == game.white_id, do: :white, else: :black

    ready? = Games.ready_game?(game)

    if ready? do
      Endpoint.broadcast_from!(self, "room:#{id}", "enter_game", %{white_username: white, black_username: black})
    end

    %{board: board,
      turn: turn,
      castling_privileges: castling_privileges,
      en_passant: en_passant,
      halfmove_clock: halfmove_clock,
      fullmoves: fullmoves} = FENParser.game_from_fen!(game.fen)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:game, game)
     |> assign(:pending, not ready?)
     |> assign(:white_player, white)
     |> assign(:black_player, black)
     |> assign(:current_player, {color, id})
     |> assign(:arangement, (if color == :white, do: {white, black}, else: {black, white}))
     |> assign(board: board, turn: turn, moves: [], selected_piece: nil, selected_piece_pos: nil, last_move: nil)
     |> assign(castling_privileges: castling_privileges, fen_en_passant: en_passant, halfmove_clock: halfmove_clock, fullmoves: fullmoves)}
  end

  @impl true
  def handle_event("exit_pending_game", _params, socket) do
    if socket.assigns.pending do
      game = socket.assigns.game
      Endpoint.broadcast_from!(self, "room:#{game.id}", "terminate", %{game_id: game.id})

      {:ok, _} = Games.delete_game(game)

      {:noreply, 
      socket
      |> assign(:game, nil)
      |> push_navigate(to: ~p"/games")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("square_click", %{"rank" => rank, "field" => field}, socket) do
    square = {rank |> String.to_integer, field |> String.to_integer}
    if destination = Enum.find(socket.assigns.moves, fn {row, col, _spec} -> {row, col} == square end) do
      send self(), {:internal, :move_piece, %{from: socket.assigns.selected_piece_pos, to: destination, user_id: socket.assigns.current_user.id}}
    else
      send self(), {:internal, :square_click, %{square: square, user_id: socket.assigns.current_user.id}}
    end
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Broadcast{event: "enter_game", payload: %{white_username: white, black_username: black}}, socket) do
    {:noreply, 
      socket
      |> assign(:white_player, white)
      |> assign(:black_player, black)
      |> assign(:pending, false)}
  end

  def handle_info(%Broadcast{event: "terminate"}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/games")}
  end

  # Handle event sent by the channel. Finalize the move on the board
  def handle_info(%Broadcast{event: "piece_move", payload: %{from: from, to: to, user_id: user_id}}, socket) do
    from = from ++ [nil] |> List.to_tuple
    to = to |> List.to_tuple
    last_move = {socket.assigns.turn, Chessboard.piece_at(socket.assigns.board, from) |> elem(1) |> elem(0), from, to}

    socket =
    socket
    |> assign(:fullmoves, (if socket.assigns.turn == :black, do: socket.assigns.fullmoves + 1, else: socket.assigns.fullmoves))
    |> assign(:halfmove_clock, (if last_move |> elem(1) == :pawn or Chessboard.piece_at(socket.assigns.board, to) != nil, do: 0, else: socket.assigns.halfmove_clock + 1))
    |> assign(:board, 
      Chessboard.move_piece(socket.assigns.board, from, to))
    |> assign(:last_move, last_move)
    |> assign(:turn, (if socket.assigns.turn == :white, do: :black, else: :white))

    if user_id == socket.assigns.current_user.id do
      spawn(fn -> handle_info({:internal, :register_move}, socket) end)
    end

    {:noreply, socket}
  end

  # Handle internal events
  # Handle the event of clicking on a highlighted square pushing the move to the client
  def handle_info({:internal, :move_piece, %{from: from, to: to, user_id: user_id}}, socket) do
    turn = socket.assigns.turn
    if socket.assigns.current_player |> elem(0) == turn do

      Endpoint.broadcast!("room:#{socket.assigns.game.id}", "piece:move", 
      %{from: from |> Tuple.to_list, to: to |> Tuple.to_list, user_id: user_id})

      castling_privileges = 
      socket.assigns.castling_privileges
      |> Chessboard.update_castling_privileges(from, Chessboard.piece_at(socket.assigns.board, from))

      {:noreply,
        socket
        |> assign(:moves, [])
        |> assign(:selected_piece_pos, nil)
        |> assign(:selected_piece, nil)
        |> assign(:castling_privileges, castling_privileges)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:internal, :square_click, %{square: square, user_id: user_id}}, socket) do
    turn = socket.assigns.turn
    if socket.assigns.current_player |> elem(0) == turn do
      moves = case Chessboard.piece_at(socket.assigns.board, square) do
        {^turn, {piece, tag}} -> 
          socket.assigns.board
          |> Chessboard.possible_moves(square)
          |> Chessboard.append_en_passant(square, {turn, {piece, tag}}, socket.assigns.last_move)
          |> Chessboard.append_castling(socket.assigns.board, socket.assigns.castling_privileges[turn], {turn, {piece, tag}})
          |> Chessboard.filter_checks(socket.assigns.board, square, {turn, {piece, tag}})
        _ -> []
      end

      Phoenix.PubSub.broadcast!(Chess.PubSub,
        "room:#{socket.assigns.game.id}",
        %{event: "square:click", payload: %{moves: moves |> Enum.map(&Tuple.to_list/1), user_id: socket.assigns.current_user.id}})
  
      {:noreply, 
        socket
        |> assign(:moves, moves)
        |> assign(:selected_piece_pos, square)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:internal, :register_move}, socket) do
    assigns = socket.assigns
    game = socket.assigns.game

    {:ok, _} =
    Games.update_game(game, 
    %{
      fen: FENParser.fen_from_game!(
        %{board: assigns.board, 
          turn: assigns.turn, 
          castling_privileges: assigns.castling_privileges, 
          en_passant: assigns.fen_en_passant, 
          halfmove_clock: assigns.halfmove_clock, 
          fullmoves: assigns.fullmoves})
    })
    
    case Games.register_move(assigns.board, assigns.last_move, assigns.fullmoves, game.id) do
      {:ok, _} -> {:noreply, socket}
      {:error, changeset} -> 
        IO.inspect(changeset)
        {:noreply, socket}
    end

    {:noreply, socket}
  end

  def handle_info(payload, socket) do
    {:noreply, socket}
  end

  defp page_title(:show), do: "Show Game"
  defp page_title(:edit), do: "Edit Game"
end
