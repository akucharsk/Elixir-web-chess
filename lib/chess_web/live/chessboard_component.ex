defmodule ChessWeb.ChessboardComponent do
    use ChessWeb, :live_component

    alias Chess.Chessboard

    @impl true
    def render(assigns) do
        ~H"""
        <div>
            <div> <%= @arangement |> elem(1) %> </div>
            <div id="chessboard" class="chessboard">
            <%= for rank <- range(@player) do %>
                <div class="row-number">
                <%= rank + 1 %>
                </div>

                <div class="chess-row">
                <%= for field <- range(@player) |> Enum.reverse do %>
                    <div 
                    class={chess_square_class(@board, rank, field)} 
                    phx-click={"square_click"} 
                    phx-value-rank={rank} 
                    phx-value-field={field}
                    id={"#{rank}_#{field}"}
                    >
                    </div>
                <% end %>
                </div>
            <% end %>
            <%= for field <- 0..7 do %>
                <div class="col-letter">
                <%= if @player |> elem(0) == :white, do:  <<?A + field>>, else: <<?H - field>> %>
                </div>
            <% end %>
            </div>
            <div> <%= @arangement |> elem(0) %> </div>
        </div>
        """
      end

    @impl true
    def update(%{game: _game} = assigns, socket) do
        {:ok,
        socket
        |> assign(assigns)}
    end
    
    defp chess_square_class(board, row, col) do
        cls = if rem(row + col, 2) == 1, do: "white-square", else: "black-square"
        case Chessboard.piece_at(board, {row, col}) do
            nil -> cls
            {_, {_, tag}} -> "#{cls} #{tag}"
        end
    end

    defp range({:white, _}), do: 7..0
    defp range({:black, _}), do: 0..7
end