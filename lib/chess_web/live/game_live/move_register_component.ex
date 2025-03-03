defmodule ChessWeb.GameLive.MoveRegisterComponent do
    use ChessWeb, :live_component

    @impl true
    @spec render(any()) :: Phoenix.LiveView.Rendered.t()
    def render(assigns) do
        ~H"""
        <div id="recorder" class="bg-zinc-100">
            <div id="record-header" class="border-2">
                <div class="border-zinc-300 border-2 p-2" style="width: 30%;">Move</div>
                <div class="border-zinc-300 border-2 p-2" style="width: 35%;">White</div>
                <div class="border-zinc-300 border-2 p-2" style="width: 35%;">Black</div>
            </div>
        </div>
        """
    end
end
