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
    
    last_move = %{
      color: Chessboard.opposite_color(turn),
    }

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:game, game)
     |> assign(:pending, not ready?)
     |> assign(:white_player, white)
     |> assign(:black_player, black)
     |> assign(:current_player, color)
     |> assign(winner: nil, resign: false, game_over: false)
     |> assign(:arangement, (if color == :white, do: {white, black}, else: {black, white}))
     |> assign(:promotion, nil)
     |> assign(:last_move, %{color: nil, piece: nil, from: nil, to: nil, promotion: nil, capture: false, check: false, mate: false, draw: false})
     |> assign(board: board, turn: turn, moves: [], selected_piece: nil, selected_piece_pos: nil)
     |> assign(castling_privileges: castling_privileges, fen_en_passant: en_passant, halfmove_clock: halfmove_clock, fullmoves: fullmoves)}
  end

  defp load_game!(id, socket) do
    game = Games.get_game!(id)

    white = if game.white_id, do: Accounts.get_user!(game.white_id).username, else: nil
    black = if game.black_id, do: Accounts.get_user!(game.black_id).username, else: nil
    color = if socket.assigns.current_user.id == game.white_id, do: :white, else: :black

    %{board: board,
      turn: turn,
      castling_privileges: castling_privileges,
      en_passant: en_passant,
      halfmove_clock: halfmove_clock,
      fullmoves: fullmoves} = FENParser.game_from_fen!(game.fen)
    
    Phoenix.PubSub.broadcast!(Chess.PubSub, "room:#{id}", %{event: "moves:load", payload: %{moves: game.moves}})
    socket
    |> assign(:game, game)
    |> assign(:pending, not Games.ready_game?(game))
    |> assign(:white_player, white)
    |> assign(:black_player, black)
    |> assign(:current_player, color)
    |> assign(:winner, Games.get_winner(game))
    
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

    :ok =
    cond do
      socket.assigns.game_over ->
        :ok

      socket.assigns.promotion ->
        :ok

      destination = Enum.find(socket.assigns.moves, fn {row, col, _spec} -> {row, col} == square end) ->
        send self(), {:internal, :move_piece, %{from: socket.assigns.selected_piece_pos, to: destination, user_id: socket.assigns.current_user.id}}
        :ok

      true ->
        send self(), {:internal, :square_click, %{square: square, user_id: socket.assigns.current_user.id}}
        :ok
    end
    {:noreply, socket}
  end

  def handle_event("promotion_click", %{"piece" => piece}, socket) do
    
    from = socket.assigns.last_move.from |> Tuple.to_list
    to = socket.assigns.last_move.to |> Tuple.to_list

    Endpoint.broadcast!("room:#{socket.assigns.game.id}", "piece:move", 
    %{from: from, to: to, user_id: socket.assigns.current_user.id, promotion: piece})

    {:noreply, assign(socket, promotion: nil)}
  end

  def handle_event("resign", _params, socket) do
    if socket.assigns.resign do
      {:ok, _} = Games.resign(socket.assigns.game, socket.assigns.current_player)
      Phoenix.PubSub.broadcast!(Chess.PubSub, "room:#{socket.assigns.game.id}", 
        %{event: "player:resign", payload: %{user_id: socket.assigns.current_user.id}})
      {:noreply, socket}
    else
      {:noreply, assign(socket, resign: true)}
    end
  end

  def handle_event("cancel_resign", _params, socket) do
    {:noreply, assign(socket, resign: false)}
  end

  @impl true
  def handle_info(%Broadcast{event: "enter_game", payload: %{white_username: white, black_username: black}}, socket) do
    {:noreply, 
      socket
      |> assign(:white_player, white)
      |> assign(:black_player, black)
      |> assign(:pending, false)
      |> assign(:game, Games.get_game!(socket.assigns.game.id))
      |> assign(:arangement, (if socket.assigns.current_player == :white, do: {white, black}, else: {black, white}))}
  end

  def handle_info(%Broadcast{event: "terminate"}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/games")}
  end

  # Handle event sent by the channel. Finalize the move on the board
  def handle_info(%Broadcast{event: "piece_move", payload: %{from: from, to: to, user_id: user_id, promotion: promo}}, socket) do
    from = from ++ [nil] |> List.to_tuple
    to = to |> List.to_tuple

    {color, {piece_type, _}} = Chessboard.piece_at(socket.assigns.board, from)
    opposite = Chessboard.opposite_color(color)

    {capture, value} = case Chessboard.piece_at(socket.assigns.board, to) do
      nil -> {nil, 0}
      {^opposite, {piece, _}} -> {FENParser.reverse_pieces(:white)[{:white, piece}], Chessboard.piece_value(piece)}
    end

    next_board = 
    socket.assigns.board 
    |> Chessboard.move_piece(from, to)
    |> Chessboard.promote_pawn(to, promo)

    last_move = %{color: color, piece: piece_type, from: from, to: to, promotion: promo, capture: capture,
      check: Chessboard.scan_checks(next_board, opposite),
      mate: false, draw: false, twin: Chessboard.has_twin_attacker?(socket.assigns.board, from, to)}
    last_move = %{last_move | mate: last_move.check and Chessboard.cannot_move?(next_board, opposite)}
    last_move = %{last_move | draw: not last_move.mate and Chessboard.cannot_move?(next_board, color)}

    move_count = socket.assigns.fullmoves

    socket =
    socket
    |> assign(:fullmoves, (if socket.assigns.turn == :black, do: move_count + 1, else: move_count))
    |> assign(:halfmove_clock, (if last_move.piece == :pawn or last_move.capture, do: 0, else: socket.assigns.halfmove_clock + 1))
    |> assign(:board, next_board)
    |> assign(:winner, (if last_move.mate, do: Accounts.get_user!(user_id), else: nil))
    |> assign(:last_move, last_move)
    |> assign(:turn, (if socket.assigns.turn == :white, do: :black, else: :white))

    if user_id == socket.assigns.current_user.id do
      spawn(fn -> handle_info({:internal, :register_move, move_count}, socket) end)
    end

    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "player_resign", payload: %{user_id: user_id}}, socket) do
    {:noreply,
      socket
      |> assign(resign: true, game_over: true)
      |> assign(:winner, Games.opponent(socket.assigns.game, user_id))}
  end

  # Handle internal events
  # Handle the event of clicking on a highlighted square pushing the move to the client
  def handle_info({:internal, :move_piece, %{from: from, to: to, user_id: user_id}}, socket) do
    turn = socket.assigns.turn
    if socket.assigns.current_player == turn do

      socket =
      if Games.promotion?(socket.assigns.board, from, to) do
        Phoenix.PubSub.broadcast!(Chess.PubSub, "room:#{socket.assigns.game.id}", %{event: "piece:promotion", payload: %{from: from, to: to, user_id: user_id}})
        assign(socket, promotion: turn, last_move: %{socket.assigns.last_move | from: from, to: to})
      else
        Endpoint.broadcast!("room:#{socket.assigns.game.id}", "piece:move", 
        %{from: from |> Tuple.to_list, to: to |> Tuple.to_list, user_id: user_id, promotion: nil})
        socket
      end

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
    if socket.assigns.current_player == turn do
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

  def handle_info({:internal, :register_move, move_count}, socket) do
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
    
    case Games.register_move(assigns.board, assigns.last_move, move_count, game.id) do
      {:ok, move} -> 
        Phoenix.PubSub.broadcast!(Chess.PubSub, "room:#{game.id}", %{event: "move:register", move: move})
        {:noreply, socket}
      {:error, changeset} -> 
        IO.inspect(changeset, label: "Move registration error")
        {:noreply, socket |> put_flash(:error, "Unable to register move")}
    end
  end

  def handle_info(payload, socket) do
    {:noreply, socket}
  end

  defp page_title(:show), do: "Show Game"
  defp page_title(:edit), do: "Edit Game"
end
