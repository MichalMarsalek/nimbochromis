## Object holding the history of a game, type of players and omputer thinking time.

import board, movegen, search, meta
import sequtils, os, strutils, strformat, times

var thinkingTotal = 0.0
var thinkingCount = 0

type Game* = object
    ## Object holding the history of a game, type of players and omputer thinking time.
    
    history*: array[512, Board]
    historyMoves*: array[512, Move]
    ply*: int
    startingPly*: int
    players*: string
    computerTime*: float
    finished*: bool

func FEN2ply*(FEN: string): int =
    ##Loads ply from FEN.
    result = FEN.split(" ")[5].parseInt * 2
    result += int(FEN.split(" ")[1] == "b")

proc newGame*(FEN: string, players: string, computerTime: float): Game =
    ## Game constructor.
    var FEN = FEN.cleanFEN
    result = Game(players: players, computerTime: computerTime)
    result.startingPly = FEN2ply(FEN)
    result.ply = result.startingPly
    result.history[result.ply] = FEN2board(FEN)

func PGN*(game: Game): string =
    ## Generates a PGN of a game.
    ## TODO start at a starting ply rather than 0.
    var players = @["\"Maršálek, Michal\"", "\"MM-chess v"&VERSION&" (" & $game.computerTime & " s)\""]
    result &= "[White " & (if game.players[0] == 'H': players[0] else: players[1]) & "]\n"
    result &= "[Black " & (if game.players[1] == 'H': players[0] else: players[1]) & "]\n\n"
    for i in game.startingPly..<game.ply:
        if i mod 2 == 0:
            result &= $(i div 2 + 1) & ". "
        result &= game.history[i].toAlgebraic(game.historyMoves[i]) & " "

func position*(game: Game): Board =
    ## Returns current position.
    game.history[game.ply]

func FEN*(game: Game): string =
    ## Generates a FEN for the game.
    game.position.FEN.replace("?", $(game.ply div 2 + 1))

proc advance*(game: var Game, move:Move) =
    ## Advances 1 ply forward.
    if move.piece == UNDO_MOVE:
        game.ply -= 2
    else:        
        game.historyMoves[game.ply] = move
        game.history[game.ply+1] = game.position.make(move)
        game.ply += 1
        game.finished = game.position.isMate    

proc getComputerMove*(game: Game): Move =
    ## Returns the best computer move
    game.position.bestMoveTime(game.history, game.ply, game.computerTime)
    

proc advance*(game: var Game) =
    ## Advances 1 ply forward. If active player is human it reads a move from stdin, otherwise it runs a search.
    var move:Move
    if game.players[game.position.activeColor] == 'H':
        echo("Legal moves: ", game.position.genSons.mapIt(game.position.toAlgebraic(it[0])).join(", "))
        echo("What move to play?")
        move = game.position.parseAlgebraic(stdin.readLine)
        if move.piece == NULL_MOVE:
            echo "invalid move, try again"
            return
        echo "-----------"
    else:
        var thinkingStart = cpuTime()
        move = getComputerMove(game)
        thinkingTotal += cpuTime() - thinkingStart
        thinkingCount += 1
        echo fmt"####### Average thinking time: {thinkingTotal/thinkingCount.float} s #######"
        echo "-------------------------------------------"
    game.advance(move)

proc showInBrowser*(game: Game) =
    game.position.showInBrowser(game.FEN & "<br>\n" & game.PGN)


#TESTING
when isMainModule:
    var game = newGame("", "CC", 10.0)
    game.showInBrowser()
    while not game.finished:        
        game.advance()
        game.showInBrowser()