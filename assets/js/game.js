import {Socket} from "phoenix"
import {Timer} from "./timer"
import Color from "./misc/colors.js"

var timer;
var syncInterval;
var timerChannel;
var channel;

var playerColor;

function pieceOnSquare(square) {
  if (square.children.length === 0) {
    return false;
  }
  if (square.children[0].classList.length < 2) {
    return false;
  }
  const pieceTag = square.children[0].classList[1];
  return pieceTag.split("-")[0] == playerColor;
}

function positionPromotionArea(to) {
    let promotionArea = document.getElementById("promotion-pieces")
    let promotionSquare = document.getElementById(`${to[0]}_${to[1]}`)
    var rect = promotionSquare.getBoundingClientRect()
    
    promotionArea.style.top = `${rect.top + rect.height}px`
    promotionArea.style.left = `${rect.left - rect.width / 2}px`
    promotionArea.style.display = "block"
    console.log("Promotion area", promotionArea.style.top, promotionArea.style.left)
}

function highlight(square) {
  const computedStyle = window.getComputedStyle(square);
  const color = Color.fromRGB(computedStyle.backgroundColor);
  const highlightColor = Color.RED();

  square.originalColor = color.toHex();
  square.style.backgroundColor = color.weightedAverage(highlightColor, 15, 13).toHex();
  square.classList.add("highlighted");
}
  
highlighted_squares = []

function removeHighlights() {
    for (let sq of highlighted_squares) {
        el = document.getElementById(`${sq}`)
        el.style.backgroundColor = el.originalColor
        square.classList.remove("highlighted")
    }
    highlighted_squares = []
}

function createMoveGroup(move_code, id) {
    let group = document.createElement("div")
    group.classList.add("move-group")
    group.id = `move-group-${id}`

    let move_num = document.createElement("div")
    move_num.classList.add("move")
    move_num.id = `move-${id}-num`
    move_num.textContent = id

    let white_move = document.createElement("div")
    white_move.classList.add("move")
    white_move.id = `move-${id}-white`
    white_move.textContent = move_code

    let black_move = document.createElement("div")
    black_move.classList.add("move")
    black_move.id = `move-${id}-black`

    if (id % 2 == 0) {
      white_move.style.backgroundColor = "lightgray";
      black_move.style.backgroundColor = "#aaaaaa";
    } else {
      white_move.style.backgroundColor = "#aaaaaa";
      black_move.style.backgroundColor = "lightgray";
    }
    const recorder = document.getElementById("recorder");
    group.style.width = `100%`;
    move_num.style.width = "30%";
    white_move.style.width = "35%";
    black_move.style.width = "35%";

    group.appendChild(move_num)
    group.appendChild(white_move)
    group.appendChild(black_move)

    recorder.appendChild(group)
}

function registerMove(move) {
  if (move.color == "white") {
    createMoveGroup(move.move_code, move.move_number);
  } else {
    document.getElementById(`move-${move.move_number}-black`).textContent = move.move_code;
  }
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
      const moves = event.moves;
      removeHighlights();
      for (let move of moves) {
        square = document.getElementById(`${move[0]}_${move[1]}`);
        highlight(square);
        highlighted_squares.push(`${move[0]}_${move[1]}`);
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
      registerMove(event);
    })
    return chan
}

function configureDragAndDrop() {
  for (let i = 0; i < 8; i++) {
    for (let j = 0; j < 8; j++) {
      const square = document.getElementById(`${i}_${j}`);
      const piece = square.children[0];

      piece.draggable = pieceOnSquare(square);
      square.ondragover = function (event) {
        event.preventDefault();
      }

      piece.ondragstart = function (event) {
        event.stopPropagation();
        if (pieceOnSquare(square)) {
          const pieceTag = piece.classList[1];
          event.dataTransfer.setData("application/json", JSON.stringify({from: [i, j], pieceTag: pieceTag}));
          window.dispatchEvent(new CustomEvent("square:dragstart", {detail: {from: [i, j]}}));

          const img = new Image();
          
          img.src = `/images/${pieceTag}.png`;
          event.dataTransfer.setDragImage(img, img.width / 2, img.height / 2);
          piece.classList.remove(pieceTag);
        }
      }

      square.ondrop = function (event) {
        event.preventDefault();
        const data = JSON.parse(event.dataTransfer.getData("application/json"));
        const tag = data.pieceTag;
        const from = data.from;

        if (square.classList.contains("highlighted")) {
          window.dispatchEvent(new CustomEvent("square:drop:move", {detail: {from: from, to: [i, j]}}));
        } else {
          const fromSquare = document.getElementById(`${from[0]}_${from[1]}`);
          fromSquare.classList.add(tag);
        }
      }
    }
  }
}

function configureNumbering() {
  const MODEL_SQUARE = document.getElementById("0_0");
  MODEL_SQUARE.style.width = `${MODEL_SQUARE.clientHeight}px`;
  const LIGHT_SQUARE_COLOR = 
    Color.
    fromRGB(window.getComputedStyle(document.getElementById("0_1")).backgroundColor);
  const DARK_SQUARE_COLOR = 
    Color.
    fromRGB(window.getComputedStyle(MODEL_SQUARE).backgroundColor);

  const COLOR_ARRAY = [DARK_SQUARE_COLOR, LIGHT_SQUARE_COLOR];

  const board = document.getElementById("chessboard");
  const rowNumbers = document.getElementById("row-numbers");
  
  const boardClientRect = board.getBoundingClientRect();
  rowNumbers.style.height = `${MODEL_SQUARE.clientHeight * 8}px`;
  var idx = 0;
  for (const row of document.getElementsByClassName("row-number")) {
    row.style.height = `${MODEL_SQUARE.clientHeight}px`;
    row.style.fontSize = `${MODEL_SQUARE.clientHeight / 3}px`;
    row.style.width = `${MODEL_SQUARE.clientHeight / 2}px`;
    row.style.backgroundColor = COLOR_ARRAY[1 - idx % 2].toRGB();
    idx++;
  }

  idx = 0;
  for (const col of document.getElementsByClassName("col-letter")) {
    col.style.width = `${MODEL_SQUARE.clientWidth}px`;
    col.style.height = `${MODEL_SQUARE.clientWidth / 2}px`;
    col.style.fontSize = `${MODEL_SQUARE.clientWidth / 3}px`;
    col.style.backgroundColor = COLOR_ARRAY[idx % 2].toRGB();
    idx++;
  }
}

function connect() {
  const gameID = window.location.pathname.split("/")[2];
  const params = new URLSearchParams(window.location.search);
  const socket = new Socket(`/socket`, {params: {token: window.userToken}});
  socket.connect();

  const channelName = `room:${gameID}`;
  channel = joinGameChannel(socket, channelName, {});
  timerChannel = joinChannel(socket, `timer:${gameID}`, {});

  channel.push("game:info", {})
    .receive("ok", resp => {
      playerColor = resp.color;
      configureDragAndDrop();
    });

}

function createTimer() {

  const whiteTimer = document.getElementById("white-timer");
  const blackTimer = document.getElementById("black-timer");

  timer = new Timer(whiteTimer, blackTimer);

  timerChannel.on("timer:synchronize", event => {
    timer.synchronizeWithServerTime(event.white_time, event.black_time)
  })

  timer.startTimer();
  timerChannel.push("timer:play");
}

function configureMoveRegister() {
  const register = document.getElementById("recorder");
  register.style.height = `${document.getElementById("chessboard").clientHeight}px`;
  register.style.width = `${document.getElementById("chessboard").clientWidth * 0.4}px`;
}

function configureTimerLayout() {
  const timers = document.getElementById("timers");
  const chessboard = document.getElementById("chessboard");

  for (const timer of document.getElementsByClassName("timer")) {
    timer.style.width = `${chessboard.clientWidth / 5}px`;
    timer.style.height = `${chessboard.clientHeight / 8}px`;
  }
}

function requestMoves() {
  channel.push("request:moves").receive("ok", resp => {
    if (resp.moves === undefined) {
      throw "Moves not received!";
    }
    for (const move of resp.moves) {
      registerMove(move);
    }
  })
}

function configureGame() {
  configureNumbering();
  configureMoveRegister();
  requestMoves();
  // configureTimerLayout();
}

GameHooks = {
    mounted() {
      connect();
      createTimer();
      configureGame();
    },

    updated() {
      console.log("Script updated");
      configureNumbering();
      configureDragAndDrop();
    },

    destroyed() {
      console.debug("DESTROYING");
      timer.clearInterval();
      clearInterval(syncInterval);
      timerChannel.push("timer:stop");
    },

    disconnected() {
      console.debug("DISCONNECTING")
      timer.clearInterval();
      clearInterval(syncInterval);
      timerChannel.push("timer:stop");
    },

    reconnected() {
      console.debug("RECONNECTED");
      connect();
      configureGame();
    }
}

window.addEventListener("click", _event => {removeHighlights()})
window.addEventListener("white:timeout", () => {channel.push("timer:timeout", {color: "white"})});
window.addEventListener("black:timeout", () => {channel.push("timer:timeout", {color: "black"})});
window.addEventListener("square:dragstart", event => {
  channel.push("square:dragstart", {from: event.detail.from});
})

window.addEventListener("square:drop:move", event => {
  channel.push("square:drop:move", {from: event.detail.from, to: event.detail.to});
})

export default GameHooks;
