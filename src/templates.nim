import macros

#temporary
template ordinalEnums*(code: untyped): untyped =
    code
    

#Templates for iterating over set bits of bitboard
template FOR_sq_IN*(bitboard, code: untyped) {.dirty.} = 
    while bitboard != 0:
        var sq = bitboard.countTrailingZeroBits
        bitboard.clearBit(sq)
        code

template FOR_sq2_IN*(bitboard, code: untyped) {.dirty.} = 
    while bitboard != 0:
        var sq2 = bitboard.countTrailingZeroBits
        bitboard.clearBit(sq2)
        code
        