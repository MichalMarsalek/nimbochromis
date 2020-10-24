## Precalculation of various constant tables.

import bitops
import board

#PRECALC KNIGHT MOVES BB
func PRECALC_KNIGHT_MOVES*(): array[64, BB] {.compileTime.} = 
    for x in 0..7:
        for y in 0..7:
            var n = 0
            for (dx, dy) in [(-1, -2), (-1, 2), (1, -2), (1, 2), (-2, -1), (-2, 1), (2, 1), (2, -1)]:
                let X = x + dx
                let Y = y + dy
                if X in 0..7 and Y in 0..7:
                    n.setBit(X + 8*Y)
            result[x + 8*y] = n

#PRECALC KING MOVES BB
func PRECALC_KING_MOVES*(): array[64, BB] {.compileTime.} = 
    for x in 0..7:
        for y in 0..7:
            var n = 0
            for (dx, dy) in [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]:
                let X = x + dx
                let Y = y + dy
                if X in 0..7 and Y in 0..7:
                    n.setBit(X + 8*Y)
            result[x + 8*y] = n


#PRECALC PAWN CAPTURES
func PRECALC_PAWN_CAPTURES*(): array[2, array[64, BB]] {.compileTime.} = 
    for x in 0..7:
        for y in 0..7:
            var n = 0
            for (dx, dy) in [(-1, -1), (1, -1)]:
                let X = x + dx
                let Y = y + dy
                if X in 0..7 and Y in 0..7:
                    n.setBit(X + 8*Y)
            result[1][x + 8*y] = n
    
    for x in 0..7:
        for y in 0..7:
            var n = 0
            for (dx, dy) in [(-1, 1), (1, 1)]:
                let X = x + dx
                let Y = y + dy
                if X in 0..7 and Y in 0..7:
                    n.setBit(X + 8*Y)
            result[0][x + 8*y] = n


#PRECALC ROOK MOVES
func PRECALC_ROOK_MOVES*(): array[64, BB] {.compileTime.} = 
    for x in 0..7:
        for y in 0..7:
            var n = 0
            for am in 1..7:
                for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)]:
                    let X = x + am*dx
                    let Y = y + am*dy
                    if X in 0..7 and Y in 0..7:
                        n.setBit(X + 8*Y)
            result[x + 8*y] = n


#PRECALC BISHOP MOVES
func PRECALC_BISHOP_MOVES*(): array[64, BB] {.compileTime.} = 
    for x in 0..7:
        for y in 0..7:
            var n = 0
            for am in 1..7:
                for (dx, dy) in [(1, 1), (-1, 1), (-1, -1), (1, -1)]:
                    let X = x + am*dx
                    let Y = y + am*dy
                    if X in 0..7 and Y in 0..7:
                        n.setBit(X + 8*Y)
            result[x + 8*y] = n

#PRECALC RAYS
func PRECALC_RAYS*(): array[8, array[64, BB]] {.compileTime.} = 
    let dirs = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    for i in 0..7:
        for x in 0..7:
            for y in 0..7:
                var n = 0
                for am in 1..7:
                    let X = x + am*dirs[i][0]
                    let Y = y + am*dirs[i][1]
                    if X in 0..7 and Y in 0..7:
                            n.setBit(X + 8*Y)
                result[i][x + 8*y] = n

#const res = PRECALC_PAWN_CAPTURES()

#echo $$res[WHITE][B1]
    
