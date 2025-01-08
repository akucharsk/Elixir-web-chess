defmodule ChessWeb.GameLive.Index do
  use ChessWeb, :live_view

  alias Chess.Games
  alias Chess.Timer

  alias Chess.Accounts

  alias ChessWeb.Endpoint
  alias Chess.GameSupervisor

  @times %{
    white_time: Time.new!(0, 10, 0, 0),
    black_time: Time.new!(0, 10, 0, 0)
  }

  @impl true
  def mount(_params, session, socket) do
    user = Accounts.get_user_by_session_token(session["user_token"])
    Endpoint.subscribe("room:lobby")
    Phoenix.PubSub.subscribe(Chess.PubSub, "room:lobby")
    {:ok,
      socket
      |> assign(:current_user, user)
      |> assign(:waiting, false)
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

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Games")
    |> assign(:game, nil)
  end

  @impl true
  def handle_info({ChessWeb.GameLive.FormComponent, {:saved, game}}, socket) do
    {:noreply, stream_insert(socket, :games, game)}
  end

  @impl true
  def handle_info(%{event: "ready_game", payload: %{game_id: game_id}}, socket) do
    if game_id == socket.assigns.game.id and socket.assigns.waiting do
      {:noreply,
        socket
        |> assign(:waiting, false)
        |> push_navigate(to: ~p"/games/#{game_id}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
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

  @impl true
  def handle_event("cancel_waiting", %{}, socket) do
    {:ok, _} = Games.delete_game(socket.assigns.game)

    {:noreply,
    assign(socket, :waiting, false)
    |> assign(:game, nil)}
  end

  @impl true
  def handle_event("new_game", %{}, socket) do
    socket =
    case Games.fetch_ready_game(socket.assigns.current_user.id) do
      {:ready, {:ok, game}} ->

        Phoenix.PubSub.broadcast!(Chess.PubSub, "room:lobby",
          %{event: "ready_game", payload: %{game_id: game.id, white_id: game.white_id, black_id: game.black_id}}
        )

        socket
        |> assign(:game, game)
        |> push_navigate(to: ~p"/games/#{game.id}")
      {:pending, {:ok, game}} ->
        socket
        |> assign(:game, game)
        |> assign(:waiting, true)
      {_, {:error, reason}} ->
        socket
        |> put_flash(:error, "Unable to create or join a game. Reason: #{reason}")
    end

    {:noreply, socket}
  end
end
