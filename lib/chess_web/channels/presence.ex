defmodule ChessWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :chess,
    pubsub_server: Chess.PubSub

  @impl true
  def init(opts \\ %{}), do: {:ok, opts}

  
end
