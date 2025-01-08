defmodule ChessWeb.TimerChannel do
  use ChessWeb, :channel
  require Logger

  alias Chess.Timer
  alias Chess.Games

  @impl true
  def join("timer:" <> game_id, _payload, socket) do
    game_id = String.to_integer(game_id)
    {:ok, assign(socket, game_id: game_id, stop_requests: 0)}
  end

  @impl true
  def handle_in("timer:stop", _payload, socket) do
    :ok = update_times(socket.assigns.game_id)
    Timer.stop(socket.assigns.game_id)

    {:noreply, socket}
  end

  @impl true
  def handle_in("timer:play", _payload, socket) do
    :ok = Timer.play(socket.assigns.game_id)
    :ok = Timer.synchronize(socket.assigns.game_id)
    {:noreply, assign(socket, :stop_requests, max(0, socket.assigns.stop_requests - 1))}
  end

  @impl true
  def handle_in("terminate", _payload, socket) do
    :ok = update_times(socket.assigns.game_id)
    :ok = Timer.stop(socket.assigns.game_id)
    {:stop, :normal, socket}
  end

  @impl true
  def handle_info(%{white_time: white_time, black_time: black_time}, socket) do
    push(socket, "timer:synchronize", %{white_time: white_time, black_time: black_time, game_id: socket.assigns.game_id})
    {:noreply, socket}
  end

  defp update_times(game_id) do
    %{white_time: white_time, black_time: black_time} = Timer.get_times(game_id)

    {:ok, _game} = Games.update_game(game_id, %{white_time: white_time, black_time: black_time})
    Logger.info(%{white: white_time, black: black_time})

    :ok
  end

end
