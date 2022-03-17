## This module defines the thinking process
## TODO - consider using a PV search instead of regular AB-negamax.
## TODO: transposition tables

import os, times, algorithm, sequtils, strutils, sugar, strformat
import board, movegen, evaluation

#TODO: procs or funcs?
var positions:int = 0

const doQuiescence = true
const debugSlowPlay = true

var rootSons: seq[(int, Move, Board)]
var maxQuiesceDepth: int

var history: array[512, Board]
var ply: int

var ECHOTHINKING = true

func present(position: Board, sons: seq[(int, Move, Board)], amount: int): string =
    result = sons[0..<min(amount, sons.len)].mapIt(position.toAlgebraic(it[1]) & "(" & position.formatScore(it[0]) & ")").join(", ")
    if sons.len > amount:
        result &= ", ..."
    

func movesComparison(a, b: (Move, Board)): int =
    ## Comparison function for move ordering. Moves are ordered in the following order:
    ## winning captures < bad noncaptures < good noncaptures < losing captures
    if a[0].capturedPiece == NO_PIECE and b[0].capturedPiece == NO_PIECE:
        let color = 1-a[1].activeColor
        return -cmp(pieceImprovement(a[0].piece, a[0].frm, a[0].to, color), pieceImprovement(b[0].piece, b[0].frm, b[0].to, color))
    if a[0].capturedPiece == NO_PIECE:
        if b[0].piece > b[0].capturedPiece:
            return -1
        return 1
    if b[0].capturedPiece == NO_PIECE:
        if a[0].piece > a[0].capturedPiece:
            return 1
        return -1
    return -cmp(a[0].capturedPiece, b[0].capturedPiece)

proc quiesce(father:Board, α, β, depth: int): int = 
    ## Performs the quiescence search. That is only considers captures and promotions below the node father, unless of course, in check.
    history[ply] = father
    let standPat = eval(father, history, ply, depth)
    positions += 1
    for i in countup(4, 1000, 2): #TODO: make a proc for this
        if i > father.move50:
            break
        if father == history[ply-i]:
            return 0
    maxQuiesceDepth = max(maxQuiesceDepth, depth)
    when not doQuiescence:
        return standPat
    else:        
        var α = α
        if standPat >= β:
            return β;
        if α < standPat:
            α = standPat
        
        var sons: seq[(Move, Board)]
        if father.isCheck:
            sons = genSons(father)
        else:
            sons = genQuiescenceSons(father)
        sons.sort(movesComparison)
        for (move, son) in sons:
            ply += 1
            var score = - quiesce(son, -β, -α, depth+1)
            ply -= 1
            if score >= β:
                return β
            if score > α:
                α = score
        return α

proc negamax(father:Board, α, β, depthLeft, depth: int): int =
    ## Performs a negamax with alphabeta pruning.
    
    history[ply] = father
    positions += 1
    for  i in countup(4, 1000, 2): #TODO: make a proc for this
        if i > father.move50:
            break
        if father == history[ply-i]:
            return 0
    var α = α
    if depthLeft == 0:
        return quiesce(father, α, β, depth)
    var sons = genSons(father)
    sons.sort(movesComparison)
    for (move, son) in sons:
        ply += 1
        var score = - negamax(son, -β, -α, depthLeft - 1, depth+1)
        ply -= 1
        if score >= β:
            return β
        if score > α:
            α = score
    if sons.len == 0:
        return eval(father, history, ply, depth)
    return α

proc rootSearch*(position: Board, depthLeft:int) =
    ## Performs the root search.
    ## Temporary: best root move from the previous iteration is searched first.
    ## TODO: order all the moves
    
    positions = 0
    maxQuiesceDepth = 0
    var bestScore = -99999
    var α = -100000
    var β = 100000
    if depthLeft == 0:
        rootSons = @[]
        var sons = genSons(position)
        sons.sort(movesComparison)
        for i in 0..<sons.len:
            rootSons.add((bestScore, sons[i][0], sons[i][1]))
    if rootSons.len == 1:
        return
    for i in 0..<rootSons.len:
        ply += 1
        let score = -negamax(rootSons[i][2], -β, -α, depthLeft, 1)
        ply -= 1
        if score > bestScore:
            bestScore = score
        #TODO
        #its faster to constrain the search window,
        #but we don't get exact scores for moves except for PV:
        #getting exact scores can be useful for root mover ordering and
        #for some heuristics - when all but 1 move suck, play it
        #it can also be useful for pondering more than 1 enemy move
        #if score > α: 
        #    α = score
        rootSons[i][0] = score
    rootSons.sort((x,y) => -cmp(x[0],y[0]))

proc bestMoveTime*(position: Board, hist: array[512, Board], plyy: int, thinkLimit:float): Move = 
    ## Iterative deeepening search. Estimates how long a next iteration search would run prior to starting it.
    ## The goal is for the overall search to take around `thinkLimit` seconds.
    ## Experiments show that in average the search takes around 1.2 times less time than it should. To compensate for this, we scale the limit by this constant.
    var thinkLimit = thinkLimit * 1.2
    var depth = 0
    var thinkingStart = cpuTime()
    var think1, think2, think3, thinkIter: float #previous time, current time, next iteration estimated time
    var pos:int
    var branchFactor:float = 1.0
    var bestScore:int
    while depth <= 3 or thinkIter <= 0.05 or (abs(thinkLimit-think2) > abs(thinkLimit-think3)):
        history = hist
        ply = plyy
        think1 = think2
        var thinkingIterStart = cpuTime()
        position.rootSearch(depth)
        result = rootSons[0][1]
        bestScore = rootSons[0][0]
        think2 = cpuTime() - thinkingStart
        if ECHOTHINKING:
            echo(fmt"Depth: {depth}, estimated: {think3:6.4f} s, real: {think2:6.4f} s, moves: ", position.present(rootSons, 3))
        think3 = think2 * branchFactor
        branchFactor = think2 / think1
        #if branchFactor < 3.5:
        #    branchFactor = 3.5
        thinkIter = cpuTime() - thinkingIterStart
        pos = positions
        depth += 1
        if bestScore > CHECKMATE_BOUND or bestScore < -CHECKMATE_BOUND or rootSons.len == 1:
            break
    if cpuTime() - thinkingStart < 1.5:
        sleep(1500 - int((cpuTime() - thinkingStart)*1000))
    if ECHOTHINKING:
        echo("Depth: ", depth-1)
        echo("Max depth: ", maxQuiesceDepth)
        echo("Branching factor: ", branchFactor)
        echo("Best move: ", position.toAlgebraic(result))
        echo("Score: ", position.formatScore(bestScore))
        echo("Thinking time: ", think2)
        echo("Positions: ", pos)
        echo("Positions/sec: ", pos.float/thinkIter)
        echo("--------------------------------------------")