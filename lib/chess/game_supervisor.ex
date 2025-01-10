defmodule Chess.GameSupervisor do
  use DynamicSupervisor

  @spec start_link(any) :: Supervisor.on_start()
  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec create_timer(map()) :: DynamicSupervisor.on_start_child()
  def create_timer(%{white_time: _, black_time: _, game_id: _} = spec) do
    DynamicSupervisor.start_child(__MODULE__, {Chess.Timer, spec})
  end

  @spec terminate_timer(integer()) :: :ok
  def terminate_timer(game_id) do
    {pid, _} = Registry.lookup(Chess.Registry, {Chess.Timer, game_id}) |> List.first
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
