defmodule ChessWeb.GameLive.Show do
  use ChessWeb, :live_view

  alias Chess.Games
  alias Chess.Accounts
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
     |> assign(:black_player, black)}
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

  def handle_info(payload, socket) do
    {:noreply, socket}
  end

  defp page_title(:show), do: "Show Game"
  defp page_title(:edit), do: "Edit Game"
end
