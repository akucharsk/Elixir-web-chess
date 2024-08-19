defmodule ChessWeb.GameLive.ChessboardComponent do
    use ChessWeb, :live_component

    alias Chess.Games

    def render(assigns) do
        ~H"""
        <div>
            <div> <%= @arangement |> elem(0) %> </div>
            <div id="chessboard" class="chessboard">
            <%= for rank <- range(@player) do %>
                <div class="row-number">
                <%= rank + 1 %>
                </div>

                <div class="chess-row">
                <%= for field <- 0..7 do %>
                    <div 
                    class={chess_square_class(rank, field)} 
                    phx-click={"square_click"} 
                    phx-value-rank={rank} 
                    phx-value-field={field}
                    id={"#{rank}_#{field}"}
                    >
                        <%= piece_at(@board, {rank, field}) %>
                    </div>
                <% end %>
                </div>
            <% end %>
            <%= for field <- 0..7 do %>
                <div class="col-letter">
                <%= <<?A + field>> %>
                </div>
            <% end %>
            </div>
            <div> <%= @arangement |> elem(1) %> </div>
        </div>
        """
      end

    @impl true
    def update(%{game: game} = assigns, socket) do
        {:ok,
        socket
        |> assign(assigns)
        |> assign(:board, generate_board())}
    end
    
    defp chess_square_class(row, col) do
        if rem(row + col, 2) == 0, do: "white-square", else: "black-square"
    end
    
    defp piece_at(board, {row, col}) do
        case Map.get(board, {row, col}) do
        nil -> ""
        piece -> piece
        end
    end

    defp range({atom, _}) do
        if atom == :white, do: 0..7, else: 7..0
    end

    defp generate_board() do
        white_pieces = ["WR", "WN", "WB", "WQ", "WK", "WB", "WN", "WR"]
        black_pieces = ["BR", "BN", "BB", "BQ", "BK", "BB", "BN", "BR"]

        %{
        {0, 0} => "WR",
        {0, 1} => "WN",
        {0, 2} => "WB",
        {0, 3} => "WQ",
        {0, 4} => "WK",
        {0, 5} => "WB",
        {0, 6} => "WN",
        {0, 7} => "WR",
        {1, 0} => "WP",
        {1, 1} => "WP",
        {1, 2} => "WP",
        {1, 3} => "WP",
        {1, 4} => "WP",
        {1, 5} => "WP",
        {1, 6} => "WP",
        {1, 7} => "WP",
        {6, 0} => "BP",
        {6, 1} => "BP",
        {6, 2} => "BP",
        {6, 3} => "BP",
        {6, 4} => "BP",
        {6, 5} => "BP",
        {6, 6} => "BP",
        {6, 7} => "BP",
        {7, 0} => "BR",
        {7, 1} => "BN",
        {7, 2} => "BB",
        {7, 3} => "BQ",
        {7, 4} => "BK",
        {7, 5} => "BB",
        {7, 6} => "BN",
        {7, 7} => "BR"
        }
    end
end