defmodule ChessWeb.RoomChannel do
  use ChessWeb, :channel
  
  alias ChessWeb.Presence

  @impl true
  def join("room:lobby", %{"name" => name} = payload, socket) do
    send self(), :after_join
    socket
    |> assign(:name, name)
    |> authorize_socket(payload)
  end

  def join("room:lobby", payload, socket) do
    authorize_socket socket, payload
  end

  def join("room:" <> game_id, payload, socket) do
    send self(), {:after_join, game_id}
    socket
    |> assign(:game_id, game_id)
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
    send self, :enter_game
    {:noreply, socket}
  end

  def handle_in("terminate", _reason, socket) do
    {:stop, :leave, socket}
  end

  def handle_in("square:click", payload, socket) do
    IO.inspect(socket)
    {:noreply, socket}
  end

  def handle_in("piece:move", payload, socket) do
    send self(), %{event: "piece:move", payload: payload}
    {:noreply, socket}
  end

  def handle_in(event, _payload, socket) do
    IO.warn("Unhandled event: #{event}")
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
    {:noreply, socket}
  end

  def handle_info(%{event: "square:click", payload: %{moves: moves, user_id: user_id}}, socket) do
    if socket.assigns.current_user_id == user_id do
      push(socket, "square:click", %{moves: moves})
    end
    {:noreply, socket}
  end

  def handle_info(%{event: "piece:move", payload: %{"from" => from, "to" => to, "user_id" => user_id, "promotion" => promo}}, socket) do
    if socket.assigns.current_user_id == user_id do
      broadcast!(socket, "piece_move", %{from: from, to: to, user_id: user_id, promotion: promo})
    end
    {:noreply, socket}
  end

  def handle_info(%{event: "move:register", move: move}, socket) do
    push(socket, "move:register", %{move_code: move.move_code, color: move.color, move_count: move.move_number})
    {:noreply, socket}
  end

  def handle_info(%{event: "player:resign", payload: %{user_id: user_id}}, socket) do
    if socket.assigns.current_user_id == user_id do
      broadcast!(socket, "player_resign", %{user_id: user_id})
    end
    {:noreply, socket}
  end

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

  @impl true
  def terminate(reason, _socket) do
    {:shutdown, reason}
  end
end
