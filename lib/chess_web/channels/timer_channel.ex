defmodule ChessWeb.TimerChannel do
  use ChessWeb, :channel
  require Logger

  @impl true
  def join("timer:" <> game_id, _payload, socket) do
    game_id = String.to_integer(game_id)
    {:ok, assign(socket, :game_id, game_id)}
  end

  @impl true
  def handle_info(%{white_time: white_time, black_time: black_time}, socket) do
    push(socket, "timer:synchronize", %{white_time: white_time, black_time: black_time})
    {:noreply, socket}
  end
end
