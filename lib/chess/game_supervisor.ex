defmodule Chess.GameSupervisor do
    use DynamicSupervisor

    @spec start_link(term()) :: Supervisor.on_start()
    def start_link(opts) do
        DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
    end

    @impl true
    def init(_init_arg) do
        DynamicSupervisor.init(strategy: :one_for_one)
    end

    @spec create_timer(map()) :: DynamicSupervisor.on_start_child()
    def create_timer(%{white_time: _, black_time: _} = args) do
        DynamicSupervisor.start_child(__MODULE__, {Chess.Timer, args})
    end
end
