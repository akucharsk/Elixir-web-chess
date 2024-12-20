defmodule Chess.Timer do
  use GenServer

  @spec start_link(map()) :: GenServer.on_start()
  def start_link(%{white_time: _, black_time: _, game_id: _} = spec) do
    GenServer.start_link(__MODULE__, spec, name: via_tuple(spec))
  end

  defp via_tuple(%{game_id: game_id}) do
    {:via, Registry, {Chess.Registry, {Chess.Timer, game_id}}}
  end

  defp via_tuple(game_id) do
    {:via, Registry, {Chess.Registry,{Chess.Timer, game_id}}}
  end

  @impl true
  def init(state) do
    state = Map.merge(state,
      %{confirmation: %{white: false, black: false}, turn: :white, last_time: nil}
    )
    {:ok, state}
  end

  defp send_updates() do
    Process.send_after(self(), :tick, 5000)
  end

  # Public API
  def confirm(color, game_id) when color in [:white, :black] do
    GenServer.cast(via_tuple(game_id), {:confirm, color})
  end

  def switch(game_id) do
    GenServer.cast(via_tuple(game_id), :switch)
  end

  def get_times(game_id) do
    GenServer.call(via_tuple(game_id), :get_times)
  end

  def stop(game_id) do
    GenServer.stop(via_tuple(game_id))
  end

  # Server callbacks
  @impl true
  def handle_cast({:confirm, color}, %{confirmation: confirmation} = state) do
    confirmation = %{confirmation | color => true}
    state = %{state | confirmation: confirmation}
    if Enum.all?(confirmation, fn {_color, confirmed} -> confirmed end) do
      send_updates()
      {:noreply, %{state | last_time: DateTime.utc_now()}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:switch, state) do
    state = subtract_times(state)
    case state.turn do
      :white -> {:noreply, %{state | turn: :black}}
      :black -> {:noreply, %{state | turn: :white}}
    end
  end

  @impl true
  def handle_call(:get_times, _from, state) do
    state = subtract_times(state)
    {:reply, %{white_time: state.white_time, black_time: state.black_time}, state}
  end

  @impl true
  def handle_info(:tick, state) do
    state = subtract_times(state)

    Phoenix.PubSub.broadcast(Chess.PubSub, "timer:#{state.game_id}",
      %{white_time: state.white_time, black_time: state.black_time}
    )

    send_updates()
    {:noreply, state}
  end

  defp subtract_times(%{last_time: last_time} = state) do
    diff = DateTime.diff(last_time, DateTime.utc_now(), :millisecond)
    case state.turn do
      :white -> %{state | white_time: Time.add(state.white_time, diff, :millisecond), last_time: DateTime.utc_now()}
      :black -> %{state | black_time: Time.add(state.black_time, diff, :millisecond), last_time: DateTime.utc_now()}
    end
  end
end
