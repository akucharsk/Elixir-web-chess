defmodule ChessWeb.GameLive.ChessboardComponent do
    use ChessWeb, :live_component

    alias Chess.Chessboard

    @impl true
    @spec render(any()) :: Phoenix.LiveView.Rendered.t()
    def render(assigns) do
        ~H"""
        <div id="game-render-frame" phx-hook="Game">

            <div id="timers" style="float: left; display: flex; flex-direction: column; align-items: flex-start;">
                <div id={timer_id(@opponent_color)} class="timer"></div>
                <div id={timer_id(@player_color)} class="timer"></div>
            </div>
            <div id="chessboard-border">
                <div id="opponent-box"> <%= @arangement |> elem(1) %> </div>
                <.promotion_pieces promotion={@promotion} color={@player_color} />

                <div id="chessboard" class="chessboard">
                    <div id="row-numbers">
                        <%= for rank <- range(@player_color) do %>
                            <div class="row-number">
                            <%= rank + 1 %>
                            </div>
                        <% end %>
                    </div>
                    <div>
                        <%= for rank <- range(@player_color) do %>

                            <div class="chess-row">
                            <%= for field <- range(@player_color) |> Enum.reverse do %>
                                <div
                                    class={chess_square_class(rank, field)}
                                    phx-click={"square_click"}
                                    phx-value-rank={rank}
                                    phx-value-field={field}
                                    id={"#{rank}_#{field}"}
                                    draggable="false"
                                >
                                    <div class={piece_class(@board, rank, field)} style="width: 100%; height: 100%"></div>
                                </div>
                            <% end %>
                            </div>
                        <% end %>
                        <div id="col-letters">
                            <%= for field <- 0..7 do %>
                                <div class="col-letter">
                                <%= if @player_color == :white, do:  <<?A + field>>, else: <<?H - field>> %>
                                </div>
                            <% end %>
                        </div>
                    </div>
                </div>
                <div> <%= @arangement |> elem(0) %> </div>
            </div>
            <div id="move-register">
                <.live_component
                module={ChessWeb.GameLive.MoveRegisterComponent}
                id={@user.id}
                />
            </div>
        </div>
        """
      end

    defp promotion_pieces(assigns) do
        ~H"""
            <div id="promotion-pieces">
                <div :if={@promotion} class="promotion-area">
                    <div class={"promotion-piece #{@color}-knight"} id="promo-knight" phx-click="promotion_click" phx-value-piece="N"></div>
                </div>
                <div :if={@promotion} class="promotion-area">
                    <div class={"promotion-piece #{@color}-rook"} id="promo-rook" phx-click="promotion_click" phx-value-piece="R"></div>
                    <div class={"promotion-piece #{@color}-queen"} id="promo-queen" phx-click="promotion_click" phx-value-piece="Q"></div>
                    <div class={"promotion-piece #{@color}-bishop"} id="promo-bishop" phx-click="promotion_click" phx-value-piece="B"></div>
                </div>
            </div>
        """
    end

    @impl true
    def update(%{game: _game} = assigns, socket) do
        {:ok,
        socket
        |> assign(assigns)}
    end

    defp chess_square_class(row, col) do
        if rem(row + col, 2) == 1, do: "white-square", else: "black-square"
    end

    defp piece_class(board, rank, file) do
        case Chessboard.piece_at(board, {rank, file}) do
            {_, {_, tag}} -> "piece #{tag}"
            _ -> ""
        end
    end

    defp range(:white), do: 7..0//-1
    defp range(:black), do: 0..7

    defp timer_id(:white), do: "white-timer"
    defp timer_id(:black), do: "black-timer"
end
