## Playable chess.

import strutils
import game, board

echo "Welcome to MM chess. Enter FEN of starting position or empty line for default"
let FEN = stdin.readLine

echo "Type CC, CH, HC or HH to determine if computer or human should play white/black."
let players = stdin.readLine

var computerTime:float
if 'C' in players:
    echo "How long (secs) should computer think?"
    computerTime = stdin.readLine.parseFloat

echo "Game is starting."
if 'H' in players:  
    echo "When it's your turn type moves in the console."
    
var gm = newGame(FEN, players, computerTime)
gm.showInBrowser()

while not gm.finished:
    gm.advance()
    gm.showInBrowser()