defmodule ChessWeb.GameLive.ChessboardComponent do
    use ChessWeb, :live_component

    alias Chess.Games

    def render(assigns) do
        ~H"""
        <div id="chessboard" class="chessboard">
          <%= for row <- 0..7 do %>
            <div class="chess-row">
              <%= for col <- 0..7 do %>
                <div class={chess_square_class(row, col)}>
                  <%= piece_at(@board, {row, col}) %>
                </div>
              <% end %>
            </div>
          <% end %>
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

    defp generate_board() do
        %{
        {0, 0} => "♜",
        {0, 1} => "♞",
        {0, 2} => "♝",
        {0, 3} => "♛",
        {0, 4} => "♚",
        {0, 5} => "♝",
        {0, 6} => "♞",
        {0, 7} => "♜",
        {1, 0} => "♟",
        {1, 1} => "♟",
        {1, 2} => "♟",
        {1, 3} => "♟",
        {1, 4} => "♟",
        {1, 5} => "♟",
        {1, 6} => "♟",
        {1, 7} => "♟",
        {6, 0} => "♙",
        {6, 1} => "♙",
        {6, 2} => "♙",
        {6, 3} => "♙",
        {6, 4} => "♙",
        {6, 5} => "♙",
        {6, 6} => "♙",
        {6, 7} => "♙",
        {7, 0} => "♖",
        {7, 1} => "♘",
        {7, 2} => "♗",
        {7, 3} => "♕",
        {7, 4} => "♔",
        {7, 5} => "♗",
        {7, 6} => "♘",
        {7, 7} => "♖"
        }
    end
end