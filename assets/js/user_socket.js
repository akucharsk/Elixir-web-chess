// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// Bring in Phoenix channels client library:
import {Socket, Presence} from "phoenix"

// And connect to the path in "lib/chess_web/endpoint.ex". We pass the
// token for authentication. Read below how it should be used.
let socket = new Socket("/socket", {params: {token: window.userToken}})

// When you connect, you'll often need to authenticate the client.
// For example, imagine you have an authentication plug, `MyAuth`,
// which authenticates the session and assigns a `:current_user`.
// If the current user exists you can assign the user's token in
// the connection for use in the layout.
//
// In your "lib/chess_web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "lib/chess_web/templates/layout/app.html.heex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/3" function
// in "lib/chess_web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket, _connect_info) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1_209_600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, connect to the socket:
socket.connect()

function joinChannel(channelName, params) {
  let channel = socket.channel(channelName, params)
  channel.join()
    .receive("ok", resp => { console.log("Joined successfully", resp) })
    .receive("error", resp => { console.log("Unable to join", resp) })
  channel.on("terminate", payload => {
    console.log("Terminated", payload)
    channel.leave()
    channels.delete(channel)
  })
  return channel
}

function joinGameChannel(channelName, params) {
  chan = joinChannel(channelName, params)

  chan.on("square:click", event => {
    console.log("Square click", event)
    square_div = document.getElementById(`${event.square[0]}_${event.square[1]}`)
    square_div.style.backgroundColor = "red"
  })
  return chan
}

// Now that you are connected, you can join channels with a topic.
// Let's assume you have a channel with a topic named `room` and the
// subtopic is its id - in this case 42:
let channels = new Map()
channels.set("room:lobby", socket.channel("room:lobby", {name: window.location.search.split("=")[1]}))
let presence = new Presence(channels.get("room:lobby"))

presence.onSync(() => {

  let response = ""

  presence.list((id, {metas: [first, ...rest]}) => {
    let count = rest.length + 1
    response += `<br>${id} (count: ${count})</br>`
  })

  document.querySelector("main").innerHTML = response
})

channels.get("room:lobby").on("new_game", payload => {
  // payload = {game_id, pending}

  channels.set(`room:${payload.game_id}`, joinGameChannel(`room:${payload.game_id}`, {}))
  chan = channels.get(`room:${payload.game_id}`)
  chan.on("enter_game", payload => {
    console.log("Enter game", payload)
    chan.push("enter_game", payload)
})})

channels.get("room:lobby").join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
