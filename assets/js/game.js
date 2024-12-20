import {Socket} from "phoenix"
import {Timer} from "./timer"

var timer;
var syncInterval;

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
    highlighted_squares = []
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

function joinChannel(socket, channelName, params) {
    let channel = socket.channel(channelName, params)
    channel.join()
      .receive("ok", resp => { 
        console.log("Joined successfully", resp)
      })
      .receive("error", resp => { console.log("Unable to join", resp) })
    channel.on("terminate", payload => {
      console.log("Terminated", payload)
      channel.leave()
    })
    return channel
}
  
function joinGameChannel(socket, channelName, params) {
    chan = joinChannel(socket, channelName, params)
  
    chan.on("game_loaded", payload => {
      console.log("Game loaded", location.pathname, payload)
    })
  
    chan.on("square:click", event => {
      const moves = event.moves
      removeHighlights()
      console.log(moves);
      for (let move of moves) {
        square = document.getElementById(`${move[0]}_${move[1]}`).classList.add("highlight")
        highlighted_squares.push(`${move[0]}_${move[1]}`)
      }
    })
  
    chan.on("piece:move", event => {
      removeHighlights();
      timer.switchTimer();
      chan.push("piece:move", event)
    })
  
    chan.on("piece:promotion", event => {
      removeHighlights()
      highlighted_squares.push(`${event.to[0]}_${event.to[1]}`)
      positionPromotionArea(event.to)
    })
  
    chan.on("move:register", event => {
      if (event.color === "white") {
        createMoveGroup(event.move_code, event.move_count)
      } else {
        document.getElementById(`move-${event.move_count}-black`).textContent = event.move_code
      }
    })
    return chan
}

GameHooks = {
    mounted() {
      const gameID = window.location.pathname.split("/")[2];
      const socket = new Socket(`/socket`, {params: {token: window.userToken}});
      console.log(window.location.pathname);
      socket.connect();

      const channelName = `room:${gameID}`;
      const channel = joinGameChannel(socket, channelName, {});
      const timerChannel = joinChannel(socket, `timer:${gameID}`, {});

      const whiteTimer = document.getElementById("white-timer");
      const blackTimer = document.getElementById("black-timer");

      window.addEventListener("white:timeout", () => {channel.push("timer:timeout", {game_id: gameID, color: "white"})});
      window.addEventListener("black:timeout", () => {channel.push("timer:timeout", {game_id: gameID, color: "black"})});

      timer = new Timer(whiteTimer, blackTimer);

      timerChannel.on("timer:synchronize", event => {
        timer.synchronizeWithServerTime(event.white_time, event.black_time)
      })

      timer.startTimer();
    },

    updated() {
      console.log("Script updated");
    },

    destroyed() {
      timer.clearInterval();
      clearInterval(syncInterval);
    },

    disconnected() {
      timer.clearInterval();
      clearInterval(syncInterval);
    }
}

window.addEventListener("click", _event => {removeHighlights()})

export default GameHooks;
