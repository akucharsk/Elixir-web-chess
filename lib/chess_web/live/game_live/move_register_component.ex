defmodule ChessWeb.GameLive.MoveRegisterComponent do
    use ChessWeb, :live_component

    @impl true
    def render(assigns) do
        ~H"""
        <table id="recorder">
            <tr>
                <th>Move</th>
                <th>White</th>
                <th>Black</th>
            </tr>
        </table>
        """
    end
end