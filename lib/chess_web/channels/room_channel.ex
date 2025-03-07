defmodule ChessWeb.RoomChannel do
  use ChessWeb, :channel

  alias ChessWeb.Presence
  alias Chess.Games
  require Logger

  @impl true
  def join("room:lobby", %{"name" => name} = payload, socket) do
    send self(), :after_join
    socket
    |> assign(:name, name)
    |> authorize_socket(payload)
  end

  @impl true
  def join("room:lobby", payload, socket) do
    authorize_socket socket, payload
  end

  @impl true
  def join("room:" <> game_id, payload, socket) do
    send self(), {:after_join, game_id}

    socket
    |> assign(:game_id, String.to_integer(game_id))
    |> authorize_socket(payload)
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  def handle_in("presence_state", _payload, socket) do
    {:noreply, socket |> IO.inspect(title: "presence_state")}
  end

  def handle_in("enter_game", _payload, socket) do
    send self(), :enter_game
    {:noreply, socket}
  end

  def handle_in("game:info", _payload, socket) do
    color = Games.get_color_for_user(socket.assigns.game_id, socket.assigns.current_user_id)
    {:reply, {:ok, %{color: color}}, socket}
  end

  def handle_in("terminate", _reason, socket) do
    Phoenix.PubSub.broadcast!(Chess.PubSub, "timer:#{socket.assigns.game_id}", "terminate")
    {:stop, :leave, socket}
  end

  def handle_in("square:click", _payload, socket) do
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_in("piece:move", payload, socket) do
    send self(), %{event: "piece:move", payload: payload}
    {:noreply, socket}
  end

  def handle_in("timer:timeout", %{"color" => color}, socket) do
    Phoenix.PubSub.broadcast(Chess.PubSub, "room:#{socket.assigns.game_id}",
      %{event: "lv:timer:timeout", payload: %{color: String.to_atom(color)}}
    )
    {:noreply, socket}
  end

  def handle_in("square:dragstart", %{"from" => [rank, file]}, socket) do
    Phoenix.PubSub.broadcast(Chess.PubSub, "room:#{socket.assigns.game_id}",
      %{event: "lv:square:dragstart", payload: %{rank: rank, file: file, user_id: socket.assigns.current_user_id}}
    )
    {:noreply, socket}
  end

  def handle_in("square:drop:move", %{"from" => [from_rank, from_file], "to" => [to_rank, to_file]}, socket) do
    Phoenix.PubSub.broadcast(Chess.PubSub, "room:#{socket.assigns.game_id}",
      %{event: "lv:square:drop:move", payload: %{from: {from_rank, from_file}, to: {to_rank, to_file}, user_id: socket.assigns.current_user_id}}
    )
    {:noreply, socket}
  end

  def handle_in("request:moves", _payload, socket) do
    socket.assigns.game_id
    |> Games.list_moves()
    |> Enum.map(fn %{move_code: move_code, move_number: move_number, color: color} -> %{move_code: move_code, move_number: move_number, color: color} end)
    |> then(&{:reply, {:ok, %{moves: &1}}, socket})
  end

  def handle_in("promotion:info", _payload, socket) do
    {rank, file} = case socket.assigns.promotion_square do
      {rank, file} -> {rank, file}
      {rank, file, _} -> {rank, file}
    end
    {:reply, {:ok, "#{rank}_#{file}"}, socket}
  end

  def handle_in(event, payload, socket) do
    IO.warn("Unhandled event: #{event}, payload: #{inspect(payload)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:after_join, game_id}, socket) do
    Presence.track(socket, socket.assigns.game_id, %{
      game_id: game_id,
    })

    {:noreply, socket}
  end

  def handle_info(:enter_game, socket) do
    :ok = Phoenix.PubSub.broadcast(Chess.PubSub, "room:#{socket.assigns.game_id}",
      %{event: "lv:game_loaded", payload: %{game_id: socket.assigns.game_id}}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "ready_game", payload: %{game_id: game_id, white_id: white_id, black_id: black_id} = payload}, socket) do
    if socket.assigns.current_user_id in [white_id, black_id] do
      push(socket, "new_game", %{game_id: game_id})
    end
    {:noreply, assign(socket, Map.to_list(payload))}
  end

  def handle_info(%{event: "square:click", payload: %{moves: moves, user_id: user_id}}, socket) do
    if socket.assigns.current_user_id == user_id do
      push(socket, "square:click", %{moves: moves})
    end
    {:noreply, socket}
  end

  def handle_info(%{event: "piece:move", payload: %{"from" => from, "to" => to, "user_id" => user_id, "promotion" => promo}}, socket) do
    if socket.assigns.current_user_id == user_id do
      broadcast!(socket, "lv:piece_move", %{from: from, to: to, user_id: user_id, promotion: promo})
    end

    {:noreply, socket}
  end

  def handle_info(%{event: "piece:promotion", payload: %{from: _from, to: to, user_id: user_id}}, socket) do
    if socket.assigns.current_user_id == user_id do
      {:noreply, assign(socket, :promotion_square, to)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "move:register", move: move}, socket) do
    push(socket, "move:register", %{move_code: move.move_code, color: move.color, move_number: move.move_number})
    {:noreply, socket}
  end

  def handle_info(%{event: "player:resign", payload: %{user_id: user_id}}, socket) do
    if socket.assigns.current_user_id == user_id do
      broadcast!(socket, "player_resign", %{user_id: user_id})
    end
    {:noreply, socket}
  end

  def handle_info(%{event: "delete:game", pid: pid, user_id: user_id}, socket) do
    if socket.assigns.current_user_id == user_id do
      broadcast!(socket, "delete_game", %{pid: pid})
    end
    {:noreply, socket}
  end

  # LiveViev events sent from one to the other. They should be ignored in the channel.
  def handle_info(%{event: "lv:" <> _event}, socket) do
    {:noreply, socket}
  end

  # Default handler for unhandled messages, in general it shouldn't be invoked.
  def handle_info(msg, socket) do
    IO.warn("Unhandled message #{inspect(msg)}")
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end

  defp authorize_socket(socket, payload) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end
  defp authorize_socket(socket, message, payload) do
    if authorized?(payload) do
      {:ok, message, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def terminate(reason, _socket) do
    {:shutdown, reason}
  end
end
