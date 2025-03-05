# Chess

#### Work in progress...

### Configure your Postgres credentials
Before you start the Phoenix server make sure you have set the following environment variables
  * `POSTGRES_USER` environment variable to your Postgres username
  * `POSTGRES_PASSWORD` environment variable to your Postgres password
  * `CHESS_SECRET_KEY` environment variable with the result of the `mix phx.gen.secret` command (it generates a secure secret key for the session management in your app)

### Start your server
To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

### Accessing the application
Once the server is running you can
  * <b>Local machine</b>: visit http://localhost:4000/games (you will be prompted to log in or sign up)

If you would like to access the application from another device in your local network you should
  * <b> Acquire the local IP address of your computer</b> (for example `192.168.1.200`)
    * `ifconfig` for Linux/macOS
    * `ipconfig` for Windows
  * Substitute <i>localhost</i> with that IP address (for example http://192.168.1.200:4000/games)

### Once logged in
Once you have successfully logged in go ahead and press the `New Game` button to start playing. 

However the game won't start unless there are two clients attempting to start a game. 

To start <b> open a different browser </b> on your <b> local machine</b>, access the app through it and click `New Game`. You should see the chessboard on both browsers.

Connecting from an external device as the second client will also work of course.

<b> The game isn't perfect, but it has the essentials </b>
  * Timers (synchronized with internal server timers)
  * The ability to resign, and offer a draw
  * En passant, castling, promotions
  * A working move register

## TODO
  * Improve frontend in the game window
      * Timer positioning
      * Move register
      * Background
  * Add chatting functionality for players and spectators
