defmodule ChessWeb.GameSandboxLive.Index do
    use ChessWeb, :live_view

    @impl true
    def mount(_params, _session, socket) do
        {:ok, socket}
    end

end
