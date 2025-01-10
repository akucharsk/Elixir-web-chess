defmodule Chess.Timer do
  use GenServer
  require Logger

  @spec start_link(map()) :: GenServer.on_start()
  def start_link(%{white_time: _, black_time: _, game_id: _} = spec) do
    GenServer.start_link(__MODULE__, spec, name: via_tuple(spec))
  end

  defp via_tuple(%{game_id: game_id}) do
    via_tuple(game_id)
  end

  defp via_tuple(game_id) do
    {:via, Registry, {Chess.Registry,{Chess.Timer, game_id}}}
  end

  @impl true
  @spec init(map()) ::
          {:ok,
           %{
             :last_time => DateTime.t(),
             :running => boolean(),
             :turn => :white | :black,
             optional(any()) => any()
           }}
  def init(state) do
    Logger.info("Initializing timer for #{state.game_id}")
    state = Map.merge(state,
      %{
        turn: :white,
        last_time: DateTime.utc_now(),
        running: true
      }
    )
    send_updates()
    {:ok, state}
  end

  # Public API

  @spec switch(integer()) :: :ok
  def switch(game_id) do
    GenServer.cast(via_tuple(game_id), :switch)
  end

  @spec pause(integer()) :: :ok
  def pause(game_id) do
    GenServer.cast(via_tuple(game_id), :pause)
  end

  @spec play(integer()) :: :ok
  def play(game_id) do
    GenServer.cast(via_tuple(game_id), :play)
  end

  @spec synchronize(integer()) :: :ok
  def synchronize(game_id) do
    GenServer.cast(via_tuple(game_id), :synchronize)
  end

  @spec get_times(integer()) :: map()
  def get_times(game_id) do
    GenServer.call(via_tuple(game_id), :get_times)
  end

  @spec stop(integer()) :: :ok
  def stop(game_id) do
    GenServer.cast(via_tuple(game_id), :stop)
  end

  # Server callbacks

  @impl true
  def handle_cast(:switch, state) do
    state = subtract_times(state)
    case state.turn do
      :white -> {:noreply, %{state | turn: :black}}
      :black -> {:noreply, %{state | turn: :white}}
    end
  end

  @impl true
  def handle_cast(:pause, state) do
    Logger.info("Pausing timer for #{state.game_id}")
    {:noreply, %{state | running: false}}
  end

  @impl true
  def handle_cast(:play, state) do
    Logger.info("Playing timer for #{state.game_id}")
    send(self(), :single_tick)
    {:noreply, %{state | running: true}}
  end

  @impl true
  def handle_cast(:synchronize, state) do
    :ok = Phoenix.PubSub.broadcast(Chess.PubSub, "timer:#{state.game_id}",
      %{white_time: state.white_time, black_time: state.black_time}
    )
    {:noreply, state}
  end

  @impl true
  def handle_cast(:stop, state) do
    {:noreply, %{state | running: false}}
  end

  @impl true
  def handle_call(:get_times, _from, state) do
    state = subtract_times(state)
    {:reply, %{white_time: state.white_time, black_time: state.black_time}, state}
  end

  @impl true
  def handle_info(:tick, %{running: true} = state) do
    state = tick(state)

    send_updates()
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:single_tick, state) do
    {:noreply, tick(state)}
  end

  defp subtract_times(%{last_time: last_time} = state) do
    diff = DateTime.diff(last_time, DateTime.utc_now(), :millisecond)
    case state.turn do
      :white -> %{state | white_time: Time.add(state.white_time, diff, :millisecond), last_time: DateTime.utc_now()}
      :black -> %{state | black_time: Time.add(state.black_time, diff, :millisecond), last_time: DateTime.utc_now()}
    end
  end

  defp tick(state) do
    state = subtract_times(state)

    :ok = Phoenix.PubSub.broadcast(Chess.PubSub, "timer:#{state.game_id}",
      %{white_time: state.white_time, black_time: state.black_time}
    )
    Logger.info("TICK for #{state.game_id}", label: "TICK")

    state
  end

  defp send_updates() do
    Process.send_after(self(), :tick, 5000)
    :ok
  end
end
