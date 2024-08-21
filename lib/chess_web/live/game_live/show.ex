defmodule ChessWeb.GameLive.Show do
  use ChessWeb, :live_view

  alias Chess.Games
  alias Chess.Accounts
  alias Chess.Chessboard

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

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:game, game)
     |> assign(:pending, not ready?)
     |> assign(:white_player, white)
     |> assign(:black_player, black)
     |> assign(:current_player, {color, id})
     |> assign(:arangement, (if color == :white, do: {white, black}, else: {black, white}))
     |> assign(:board, Chessboard.generate_chessboard())
     |> assign(:turn, :white)
     |> assign(:moves, [])
     |> assign(:selected_piece_pos, nil)}
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
    if square in socket.assigns.moves do
      send self(), {:internal, :move_piece, %{from: socket.assigns.selected_piece_pos |> Tuple.to_list, to: square |> Tuple.to_list, user_id: socket.assigns.current_user.id}}
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

  def handle_info(%Broadcast{event: "piece_move", payload: %{from: from, to: to, user_id: user_id}}, socket) do
    IO.inspect({socket.assigns.current_user.username, socket.assigns.turn})
    {:noreply, 
    socket
    |> assign(:board, 
      Chessboard.move_piece(socket.assigns.board, from |> List.to_tuple, to |> List.to_tuple))
    |> assign(:turn, (if socket.assigns.turn == :white, do: :black, else: :white))}
  end

  def handle_info({:internal, :move_piece, %{from: from, to: to, user_id: user_id}}, socket) do
    turn = socket.assigns.turn
    if socket.assigns.current_player |> elem(0) == turn do
      Endpoint.broadcast!("room:#{socket.assigns.game.id}", "piece:move", %{from: from, to: to, user_id: user_id})
      {:noreply,
        socket
        |> assign(:moves, [])
        |> assign(:selected_piece_pos, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:internal, :square_click, %{square: square, user_id: user_id}}, socket) do
    turn = socket.assigns.turn

    if socket.assigns.current_player |> elem(0) == turn do
      moves = case Chessboard.piece_at(socket.assigns.board, square) do
        {^turn, {_piece, _tag}} -> 
          Chessboard.possible_moves(socket.assigns.board, square)
        _ -> []
      end
      
      Endpoint.broadcast!("room:#{socket.assigns.game.id}", "square:click", 
      %{moves: moves |> Enum.map(&Tuple.to_list/1), user_id: socket.assigns.current_user.id}
      )
  
      {:noreply, 
        socket
        |> assign(:moves, moves)
        |> assign(:selected_piece_pos, square)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(payload, socket) do
    {:noreply, socket}
  end

  defp page_title(:show), do: "Show Game"
  defp page_title(:edit), do: "Edit Game"
end
