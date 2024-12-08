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

function positionPromotionArea(to) {
  let promotionArea = document.getElementById("promotion-pieces")
  let promotionSquare = document.getElementById(`${to[0]}_${to[1]}`)
  var rect = promotionSquare.getBoundingClientRect()
  
  promotionArea.style.top = `${rect.top + rect.height}px`
  promotionArea.style.left = `${rect.left - rect.width}px`
  promotionArea.style.display = "block"
  console.log("Promotion area", promotionArea.style.top, promotionArea.style.left)
}

highlighted_squares = []

function removeHighlights() {
  for (let sq of highlighted_squares) {
    el = document.getElementById(`${sq}`)
    el.classList.remove("highlight")
  }
  highlighted_squares.length = 0
}

function createMoveGroup(move_code, id) {
  let group = document.createElement("tr")
  group.classList.add("move-group")
  group.id = `move-group-${id}`

  let move_num = document.createElement("td")
  move_num.classList.add("move")
  move_num.id = `move-${id}-num`
  move_num.textContent = id

  let white_move = document.createElement("td")
  white_move.classList.add("move")
  white_move.id = `move-${id}-white`
  white_move.textContent = move_code

  let black_move = document.createElement("td")
  black_move.classList.add("move")
  black_move.id = `move-${id}-black`

  group.appendChild(move_num)
  group.appendChild(white_move)
  group.appendChild(black_move)

  document.getElementById("recorder").appendChild(group)
}

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
    let moves = event.moves
    removeHighlights()
    for (let move of moves) {
      square = document.getElementById(`${move[0]}_${move[1]}`).classList.add("highlight")
      highlighted_squares.push(`${move[0]}_${move[1]}`)
    }
  })

  chan.on("piece:move", event => {
    removeHighlights()
    chan.push("piece:move", event)
  })

  chan.on("piece:promotion", event => {
    removeHighlights()
    highlighted_squares.push(`${event.to[0]}_${event.to[1]}`)
    positionPromotionArea(event.to)
  })

  chan.on("move:register", event => {
    console.log("Move register", event)
    if (event.color === "white") {
      createMoveGroup(event.move_code, event.move_count)
    } else {
      document.getElementById(`move-${event.move_count}-black`).textContent = event.move_code
    }
  })
  return chan
}

// Now that you are connected, you can join channels with a topic.
// Let's assume you have a channel with a topic named `room` and the
// subtopic is its id - in this case 42:
let channels = new Map()
channels.set("room:lobby", socket.channel("room:lobby", {name: window.location.search.split("=")[1]}))

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

path = window.location.pathname.split("/")
res = parseInt(path[path.length - 1])

if (!isNaN(res) && path.length === 3 && path[0] === "" && path[1] === "games") {
  channels.set(`room:${res}`, joinGameChannel(`room:${res}`, {}))
  chan = channels.get(`room:${res}`)
  chan.on("enter_game", payload => {
    console.log("Enter game", payload)
    chan.push("enter_game", payload)
  })
}

window.addEventListener("click", _event => {removeHighlights()})

export default socket
