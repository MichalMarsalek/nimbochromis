## Handles the engine, its management of time, pondering etc.
## This is a slight shift of focus towards nimbochromis being a lichessBot.

import board, movegen, search, meta, evaluation, time_management
import sequtils, os, strutils, strformat, times

var thinkingTotal = 0.0
var thinkingCount = 0

type Game* = object
    ## Object holding the history of a game, 
    history*: array[512, Board]
    historyMoves*: array[512, Move]
    ply*: int
    nimbochromisColor*: Color
    increment*: float
    remainingTime*: array[2, float]

func position*(game: Game): Board =
    ## Returns current position.
    game.history[game.ply]
    
proc updateTime*(game: var Game, white, black: float) =
    ## Updates remaining times in the game.
    game.remainingTime[WHITE] = white
    game.remainingTime[BLACK] = black
    
proc advance*(game: var Game, move:Move) =
    ## Advances 1 ply forward.
    if move.piece == UNDO_MOVE:
        game.ply -= 2
    else:        
        game.historyMoves[game.ply] = move
        game.history[game.ply+1] = game.position.make(move)
        game.ply += 1

proc advance*(game: var Game, move:string) =
    ## Advances 1 ply forward.
    game.advance(game.position.parseMove(move))

proc newGame*(moves: string, myColor: Color, increment: float): Game =
    ## Constructs a new Game object.
    result = Game(nimbochromisColor: myColor, increment: increment)    
    result.history[0] = FEN2board("".cleanFEN)
    if moves != "":
        for moveStr in moves.split(" "):
            var move = result.position.parseMove(moveStr)
            result.advance(move)

proc getMove*(game: Game): Move =
    ## Returns the best computer move
    let time = allocate_time(game.position.count_material, game.remainingTime[game.nimbochromisColor], game.remainingTime[1-game.nimbochromisColor], game.increment)
    echo("Allocated time: ", time)
    game.position.bestMoveTime(game.history, game.ply, time)
    
func isNimbochromisTurn*(game: Game): bool =
    game.ply mod 2 == game.nimbochromisColor