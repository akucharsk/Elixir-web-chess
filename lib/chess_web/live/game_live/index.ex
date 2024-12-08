defmodule ChessWeb.GameLive.Index do
  use ChessWeb, :live_view

  alias Chess.Games

  alias Chess.Accounts

  alias ChessWeb.Endpoint


  @impl true
  def mount(_params, session, socket) do
    user = Accounts.get_user_by_session_token(session["user_token"])
    Endpoint.subscribe("room:lobby")
    {:ok,
      socket
      |> assign(:current_user, user)
      |> stream(:games, Games.list_games())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Game")
    |> assign(:games, Games.get_game!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Game")

    case Games.fetch_ready_game(socket.assigns.current_user.id) do
      {:ok, game} ->
        ChessWeb.Endpoint.broadcast_from!(self(), "room:lobby", "new_game", %{game_id: game.id, pending: not Games.ready_game?(game)})
        socket
        |> assign(:game, game)
        |> push_navigate(to: ~p"/games/#{game.id}")
      {:error, changeset} ->
        IO.inspect("Unable to create or join a game")
        socket
        |> put_flash(:error, "Unable to create or join a game, reason: #{inspect(changeset)}")
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Games")
    |> assign(:game, nil)
  end

  @impl true
  def handle_info({ChessWeb.GameLive.FormComponent, {:saved, game}}, socket) do
    {:noreply, stream_insert(socket, :games, game)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do

    game = Games.get_game!(id)
    {:ok, _} = Games.delete_game(game)

    Endpoint.broadcast_from!(self(), "room:#{id}", "terminate", %{})

    {:noreply, stream_delete(socket, :games, game)}
  end

end
