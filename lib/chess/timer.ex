defmodule Chess.Timer do

    use GenServer

    @spec start_link(map()) :: GenServer.on_start()
    def start_link(opts) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    @spec child_spec(term()) :: map()
    def child_spec(opts) do
        %{
            id: opts.id,
            start: {__MODULE__, :start_link, [opts]}
        }
    end

    @impl true
    @spec init(%{:black_time => any(), :white_time => any(), optional(any()) => any()}) ::
            {:ok,
             %{
               :black_time => any(),
               :current_player => :white,
               :status => :stopped,
               :white_time => any(),
               optional(any()) => any()
             }}
    def init(%{white_time: _white_time, black_time: _black_time} = opts) do
        {:ok, Map.merge(opts, %{status: :stopped, current_player: :white})}
    end

    # API
    @spec start_timer() :: :ok
    def start_timer() do
        GenServer.cast(__MODULE__, :start_timer)
    end

    @spec stop_timer() :: :ok
    def stop_timer() do
        GenServer.cast(__MODULE__, :stop_timer)
    end

    @spec switch_timer() :: :ok
    def switch_timer() do
        GenServer.cast(__MODULE__, :switch_timer)
    end

    @spec get_times() :: {:ok, map()} | {:error, term()}
    def get_times() do
        GenServer.call(__MODULE__, :get_times)
    end

    # Server callbacks
    @impl true
    def handle_cast(:start_timer, state) do
        {:noreply, %{state | status: :running}}
    end

    @impl true
    def handle_cast(:stop_timer, state) do
        {:noreply, %{state | status: :stopped}}
    end

    @impl true
    def handle_cast(:switch_timer, %{current_player: :white} = state) do
        {:noerply, %{state | current_player: :black}}
    end

    @impl true
    def handle_cast(:switch_timer, %{current_player: :black} = state) do
        {:noreply, %{state | current_player: :white}}
    end

    @impl true
    def handle_call(:get_times, _from, state) do
        {time, player_time} =
        case state.current_player do
            :white -> {state.white_time, :white_time}
            :black -> {state.black_time, :black_time}
        end

        diff = Time.diff(time, Time.utc_now(), :millisecond)
        state = Map.put(state, player_time, Time.add(time, diff, :millisecond))
        {:reply, {:ok, state}, state}
    end
end
