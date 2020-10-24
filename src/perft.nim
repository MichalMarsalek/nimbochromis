## Perft - movegen correctness and speed benchmark.

import board
import movegen
import search
import evaluation
import random
import times

randomize()

var position = FEN2board(CHESS_STARTING_FEN)
showInBrowser position

let testStart = cpuTime()
const depth:int = 5
var positions = 0

var maxScore = 0

proc traverse(pos:Board, dep:int) = 
    positions += 1
    if dep > 0:
        for (move, son) in position.genSons:
            traverse(son, dep-1)
    else:
        let score = pos.pieces[KNIGHT].int
        if score > maxScore:
            maxScore = score

traverse(position, depth)

let testLength = cpuTime() - testStart

echo("Depth: ", depth)
echo("Positions: ", positions)
echo("Time: ", testLength)
echo("Positions/sec: ", positions.float / testLength)
