## This file defines functions for generating available moves

## TODO constants for directions?
## Directions are in CCW order, starting from EAST
## TODO introduce some neat syntax (macro) to make code more readable

import bitops, os, sequtils
import board, precalc, templates

type
    Move* = object
        ## Move object.
        piece*: Piece               ## Piece being moved. UNDO_MOVE represents a takeback
        frm*: Square                ## Departure square.
        to*: Square                 ## Destination square.
        capturedPiece*: Piece       ## Piece being captured or NO_PIECE if the move is quiet.
        promotion*: Piece           ## Piece being promoted to or NO_PIECE if the move is not a promotion.

func newMove*(piece: Piece, frm, to: Square):Move =
    ## Move constructor.
    Move(piece: piece, frm: frm, to: to, capturedPiece: NO_PIECE, promotion: NO_PIECE)

func newMove*(piece: Piece, frm, to: Square, capt: Piece):Move = 
    ## Move constructor.
    Move(piece: piece, frm: frm, to: to, capturedPiece: capt, promotion: NO_PIECE)

func newMove*(piece: Piece, frm, to: Square, capt, promotion: Piece):Move = 
    ## Move constructor.
    Move(piece: piece, frm: frm, to: to, capturedPiece: capt, promotion: promotion)

func `$`*(move: Move): string =
    ## Generates a simple UCI string representation of a move. This representation is position independant.
    ## See `toAlgebraic` for a position dependant algebraic notation repr.
    result = $move.frm & $move.to
    if move.promotion != NO_PIECE:
        result &= PIECES_LETTERS[move.piece]

func parseMove*(board:Board, s: string): Move =
    ## Parses a simple UCI (position independant) string representation of a move.
    ## See `parseAlgebraic` for a position dependant algebraic notation parsing.
    
    if s == "undo":
        return Move(piece: UNDO_MOVE)
    var act = board.activeColor
    result = Move(frm: parseSquare(s[0..1]), to: parseSquare(s[2..3]))
    result.piece = board.determinePiece(result.frm)
    if result.piece == KING and (result.frm - result.to == -2 or result.frm - result.to == 2):
        result.piece = KING_ROOK
    result.capturedPiece = board.determinePiece(result.to)
    result.promotion = NO_PIECE
    if result.piece == PAWN and (result.to <= H1 or result.to >= A8):
        for piece in PAWN..QUEEN:
            if PIECES_LETTERS[piece] == s[4]:
                result.promotion = piece

const KNIGHT_MOVES:           array[64, BB]  = PRECALC_KNIGHT_MOVES()
const KING_MOVES:             array[64, BB]  = PRECALC_KING_MOVES()
const ROOK_MOVES:             array[64, BB]  = PRECALC_ROOK_MOVES()
const BISHOP_MOVES:           array[64, BB]  = PRECALC_BISHOP_MOVES()
const PAWN_CAPTURES: array[2, array[64, BB]] = PRECALC_PAWN_CAPTURES()
const RAYS:          array[8, array[64, BB]] = PRECALC_RAYS()

#TODO preOR masks with 0x8000000000000001 to avoid branches (which might have some negative impact)
func firstSquare*(board:BB):Square {.inline.} =
    ## Returns the first set bit of a Bitboard. For Sliding pieces, its important that `EMPTY` maps to `63`.
    if board == 0: return 63
    countTrailingZeroBits(board)
func lastSquare(board:BB):Square {.inline.} =
    ## Returns the last set bit of a Bitboard. For Sliding pieces, its important that `EMPTY` maps to `0`.
    if board == 0: return 0
    63-countLeadingZeroBits(board) #TODO consider reversing the order of the array instead of 63-


func rook_moves*(occupied:BB, sq:Square):BB {.inline.} =
    ## Calculates the attack set of a rook given the occupied square BB.
    let stop0 = firstSquare(occupied & RAYS[0][sq])
    let stop2 = firstSquare(occupied & RAYS[2][sq])
    let stop4 = lastSquare(occupied & RAYS[4][sq])
    let stop6 = lastSquare(occupied & RAYS[6][sq])
    
    return ROOK_MOVES[sq] ^ RAYS[0][stop0] ^ RAYS[2][stop2] ^ RAYS[4][stop4] ^ RAYS[6][stop6]

func bishop_moves*(occupied:BB, sq:Square):BB {.inline.} =
    ## Calculates the attack set of a bishop given the occupied square BB.
    let stop1 = firstSquare(occupied & RAYS[1][sq])
    let stop3 = firstSquare(occupied & RAYS[3][sq])
    let stop5 = lastSquare(occupied & RAYS[5][sq])
    let stop7 = lastSquare(occupied & RAYS[7][sq])
    
    return BISHOP_MOVES[sq] ^ RAYS[1][stop1] ^ RAYS[3][stop3] ^ RAYS[5][stop5] ^ RAYS[7][stop7]


func isAttacked(board:Board, sq:Square, by:Color):bool =
    ## Determines whether square `sq` is being attack by any piece of color `by`.

    var occupied:BB = board.occupied
    var attackers:BB
    
    #Pawn
    attackers = PAWN_CAPTURES[1-by][sq] & board.colors[by] & board.pieces[PAWN]
    if attackers != 0: return true    
    #Knight
    attackers = KNIGHT_MOVES[sq] & board.pieces[KNIGHT] & board.colors[by]
    if attackers != 0: return true    
    #Bishop & Queen
    attackers = bishop_moves(occupied, sq) & board.colors[by] & (board.pieces[BISHOP] | board.pieces[QUEEN])
    if attackers != 0: return true    
    #Rook & Queen
    attackers = rook_moves(occupied, sq) & board.colors[by] & (board.pieces[ROOK] | board.pieces[QUEEN])
    if attackers != 0: return true
    #King - TODO eliminate checks by king in movegen
    attackers = KING_MOVES[sq] & board.pieces[KING] & board.colors[by]
    if attackers != 0: return true
    return false

func genPseudoMoves*(board: Board): seq[Move] = 
    ## Generates all pseudomoves.
    
    var free = board.free
    var act = board.active_color
    var occupied = board.occupied
    var capturable = board.colors[1-act]
    var capturableP = capturable | (1<<board.enPassant) #squares capturable by pawns ... hence ORing the enPassant square
    
    #PAWN push promotions, captures, en passant
    let myPawns = board.pieces[PAWN] & board.colors[act]
    if act == WHITE:
        var pushPromotion = myPawns & 0x00_ff_00_00_00_00_00_00 & (free>>8)
        FOR_SQ_IN pushPromotion:
            result.add(newMove(PAWN, sq,sq+8,NO_PIECE, KNIGHT))
            result.add(newMove(PAWN, sq,sq+8,NO_PIECE, BISHOP))
            result.add(newMove(PAWN, sq,sq+8,NO_PIECE, ROOK))
            result.add(newMove(PAWN, sq,sq+8,NO_PIECE, QUEEN))
        var leftCapture = myPawns & 0x00_fe_fe_fe_fe_fe_fe_00 & (capturableP >> 7)
        FOR_SQ_IN leftCapture:
            let captured = board.determinePieceCapture(sq+7)                    
            if sq >= A7:
                result.add(newMove(PAWN, sq,sq+7,captured, KNIGHT))
                result.add(newMove(PAWN, sq,sq+7,captured, BISHOP))
                result.add(newMove(PAWN, sq,sq+7,captured, ROOK))
                result.add(newMove(PAWN, sq,sq+7,captured, QUEEN))
            else:
                result.add(newMove(PAWN, sq,sq+7,captured))                
        var rightCapture = myPawns & 0x00_7f_7f_7f_7f_7f_7f_00 & (capturableP >> 9)
        FOR_SQ_IN rightCapture:
            let captured = board.determinePieceCapture(sq+9)                    
            if sq >= A7:
                result.add(newMove(PAWN, sq,sq+9,captured, KNIGHT))
                result.add(newMove(PAWN, sq,sq+9,captured, BISHOP))
                result.add(newMove(PAWN, sq,sq+9,captured, ROOK))
                result.add(newMove(PAWN, sq,sq+9,captured, QUEEN))
            else:
                result.add(newMove(PAWN, sq,sq+9,captured)) 
    else:
        var pushPromotion = myPawns & 0x00_00_00_00_00_00_ff_00 & (free<<8)
        FOR_SQ_IN pushPromotion:
            result.add(newMove(PAWN, sq,sq-8,NO_PIECE, KNIGHT))
            result.add(newMove(PAWN, sq,sq-8,NO_PIECE, BISHOP))
            result.add(newMove(PAWN, sq,sq-8,NO_PIECE, ROOK))
            result.add(newMove(PAWN, sq,sq-8,NO_PIECE, QUEEN))
        var leftCapture = myPawns & 0x00_fe_fe_fe_fe_fe_fe_00 & (capturableP << 9)
        FOR_SQ_IN leftCapture:
            let captured = board.determinePieceCapture(sq-9)                    
            if sq <= H2:
                result.add(newMove(PAWN, sq,sq-9,captured, KNIGHT))
                result.add(newMove(PAWN, sq,sq-9,captured, BISHOP))
                result.add(newMove(PAWN, sq,sq-9,captured, ROOK))
                result.add(newMove(PAWN, sq,sq-9,captured, QUEEN))
            else:
                result.add(newMove(PAWN, sq,sq-9,captured))                
        var rightCapture = myPawns & 0x00_7f_7f_7f_7f_7f_7f_00 & (capturableP << 7)
        FOR_SQ_IN rightCapture:
            let captured = board.determinePieceCapture(sq-7)                    
            if sq <= H2:
                result.add(newMove(PAWN, sq,sq-7,captured, KNIGHT))
                result.add(newMove(PAWN, sq,sq-7,captured, BISHOP))
                result.add(newMove(PAWN, sq,sq-7,captured, ROOK))
                result.add(newMove(PAWN, sq,sq-7,captured, QUEEN))
            else:
                result.add(newMove(PAWN, sq,sq-7,captured)) 
    
    #Pawns pushes (no promotions)
    var pawns1 = myPawns
    if act == WHITE:
        pawns1 = pawns1 & (free>>8) & 0x00_00_ff_ff_ff_ff_ff_00 # pawns that can push 1 square (without promoting)
        var pawns2 = pawns1 & (free >> 16) & 0x00_00_00_00_00_00_ff_00 #pawns that can push 2 squares
        FOR_SQ_IN pawns1:
            result.add(newMove(PAWN, sq,sq+8,NO_PIECE))
        FOR_SQ_IN pawns2:
            result.add(newMove(PAWN, sq, sq+16,NO_PIECE))
    else:
        pawns1 = pawns1 & (free<<8) & 0x00_ff_ff_ff_ff_ff_00_00 # pawns that can push 1 square (without promoting)
        var pawns2 = pawns1 & (free << 16) & 0x00_ff_00_00_00_00_00_00 #pawns that can push 2 squares
        FOR_SQ_IN pawns1:
            result.add(newMove(PAWN, sq,sq-8,NO_PIECE))
        FOR_SQ_IN pawns2:
            result.add(newMove(PAWN, sq,sq-16,NO_PIECE))    
    
    #TODO Consider generating captures and noncaptures together - I call determinePieces after all...
    #Knight
    var knights = board.pieces[KNIGHT] & board.colors[act]
    FOR_SQ_IN knights:
        var aval: BB = KNIGHT_MOVES[sq]
        var avalQ: BB = aval & free
        var avalC: BB = aval & capturable
        FOR_SQ2_IN avalQ:
            result.add(newMove(KNIGHT, sq,sq2,NO_PIECE))
        FOR_SQ2_IN avalC:
            result.add(newMove(KNIGHT, sq,sq2,board.determinePieceCapture(sq2)))
    
    #Bishop
    var bishops = board.pieces[BISHOP] & board.colors[act]
    FOR_SQ_IN bishops:
        var aval:BB = bishop_moves(occupied, sq)
        var avalQ: BB = aval & free
        var avalC: BB = aval & capturable
        FOR_SQ2_IN avalQ:
            result.add(newMove(BISHOP, sq,sq2,NO_PIECE))
        FOR_SQ2_IN avalC:
            result.add(newMove(BISHOP, sq,sq2,board.determinePieceCapture(sq2)))
    
    #Rooks
    var rooks = board.pieces[ROOK] & board.colors[act]
    FOR_SQ_IN rooks:
        var aval:BB = rook_moves(occupied, sq)
        var avalQ: BB = aval & free
        var avalC: BB = aval & capturable
        FOR_SQ2_IN avalQ:
            result.add(newMove(ROOK, sq,sq2,NO_PIECE))
        FOR_SQ2_IN avalC:
            result.add(newMove(ROOK, sq,sq2,board.determinePieceCapture(sq2)))
    
    #Queen
    var queens = board.pieces[QUEEN] & board.colors[act]
    FOR_SQ_IN queens:
        var aval:BB = (bishop_moves(occupied, sq) | rook_moves(occupied, sq))
        var avalQ: BB = aval & free
        var avalC: BB = aval & capturable
        FOR_SQ2_IN avalQ:
            result.add(newMove(QUEEN, sq,sq2,NO_PIECE))
        FOR_SQ2_IN avalC:
            result.add(newMove(QUEEN, sq,sq2,board.determinePieceCapture(sq2)))
    
    #King
    var king = board.pieces[KING] & board.colors[act]
    var sq = king.countTrailingZeroBits
    var aval: BB = KING_MOVES[sq]
    var avalQ: BB = aval & free
    var avalC: BB = aval & capturable
    FOR_SQ2_IN avalQ:
        result.add(newMove(KING, sq,sq2,NO_PIECE))
    FOR_SQ2_IN avalC:
        result.add(newMove(KING, sq,sq2,board.determinePiece(sq2)))
    
    #Castling
    if not board.isCheck:
        let rank = occupied >> (act*56)
        if board.canCastle[act][0] and not board.isAttacked(D1 + act*56, 1-act) and (rank & 0x0e) == 0:
            result.add(newMove(KING_ROOK, E1 + act*56, C1 + act*56,NO_PIECE))
        if board.canCastle[act][1] and not board.isAttacked(F1 + act*56, 1-act) and (rank & 0x60) == 0:
            result.add(newMove(KING_ROOK, E1 + act*56, G1 + act*56,NO_PIECE))
    
func genPseudoQuiescenceMoves*(board: Board): seq[Move] = 
    ## Generates all pseudo quiescence moves - that is captures and promotions.
    
    # only captures and promotions
    var act = board.activeColor
    var free = board.free
    var occupied = board.occupied
    var capturable = board.colors[1-act]
    var capturableP = capturable | (1<<board.enPassant) #squares capturable by pawns ... hence ORing the enPassant square

    #Pawns
    #this is ugly, but what can you do
    let myPawns = board.pieces[PAWN] & board.colors[act]
    if act == WHITE:
        var pushPromotion = myPawns & 0x00_ff_00_00_00_00_00_00 & (free>>8)
        FOR_SQ_IN pushPromotion:
            result.add(newMove(PAWN, sq,sq+8,NO_PIECE, KNIGHT))
            result.add(newMove(PAWN, sq,sq+8,NO_PIECE, BISHOP))
            result.add(newMove(PAWN, sq,sq+8,NO_PIECE, ROOK))
            result.add(newMove(PAWN, sq,sq+8,NO_PIECE, QUEEN))
        var leftCapture = myPawns & 0x00_fe_fe_fe_fe_fe_fe_00 & (capturableP >> 7)
        FOR_SQ_IN leftCapture:
            let captured = board.determinePieceCapture(sq+7)                    
            if sq >= A7:
                result.add(newMove(PAWN, sq,sq+7,captured, KNIGHT))
                result.add(newMove(PAWN, sq,sq+7,captured, BISHOP))
                result.add(newMove(PAWN, sq,sq+7,captured, ROOK))
                result.add(newMove(PAWN, sq,sq+7,captured, QUEEN))
            else:
                result.add(newMove(PAWN, sq,sq+7,captured))                
        var rightCapture = myPawns & 0x00_7f_7f_7f_7f_7f_7f_00 & (capturableP >> 9)
        FOR_SQ_IN rightCapture:
            let captured = board.determinePieceCapture(sq+9)                    
            if sq >= A7:
                result.add(newMove(PAWN, sq,sq+9,captured, KNIGHT))
                result.add(newMove(PAWN, sq,sq+9,captured, BISHOP))
                result.add(newMove(PAWN, sq,sq+9,captured, ROOK))
                result.add(newMove(PAWN, sq,sq+9,captured, QUEEN))
            else:
                result.add(newMove(PAWN, sq,sq+9,captured)) 
    else:
        var pushPromotion = myPawns & 0x00_00_00_00_00_00_ff_00 & (free<<8)
        FOR_SQ_IN pushPromotion:
            result.add(newMove(PAWN, sq,sq-8,NO_PIECE, KNIGHT))
            result.add(newMove(PAWN, sq,sq-8,NO_PIECE, BISHOP))
            result.add(newMove(PAWN, sq,sq-8,NO_PIECE, ROOK))
            result.add(newMove(PAWN, sq,sq-8,NO_PIECE, QUEEN))
        var leftCapture = myPawns & 0x00_fe_fe_fe_fe_fe_fe_00 & (capturableP << 9)
        FOR_SQ_IN leftCapture:
            let captured = board.determinePieceCapture(sq-9)                    
            if sq <= H2:
                result.add(newMove(PAWN, sq,sq-9,captured, KNIGHT))
                result.add(newMove(PAWN, sq,sq-9,captured, BISHOP))
                result.add(newMove(PAWN, sq,sq-9,captured, ROOK))
                result.add(newMove(PAWN, sq,sq-9,captured, QUEEN))
            else:
                result.add(newMove(PAWN, sq,sq-9,captured))                
        var rightCapture = myPawns & 0x00_7f_7f_7f_7f_7f_7f_00 & (capturableP << 7)
        FOR_SQ_IN rightCapture:
            let captured = board.determinePieceCapture(sq-7)                    
            if sq <= H2:
                result.add(newMove(PAWN, sq,sq-7,captured, KNIGHT))
                result.add(newMove(PAWN, sq,sq-7,captured, BISHOP))
                result.add(newMove(PAWN, sq,sq-7,captured, ROOK))
                result.add(newMove(PAWN, sq,sq-7,captured, QUEEN))
            else:
                result.add(newMove(PAWN, sq,sq-7,captured)) 
    
    #Knight
    var knights = board.pieces[KNIGHT] & board.colors[act]
    FOR_SQ_IN knights:
        var aval: BB = KNIGHT_MOVES[sq] & capturable
        FOR_SQ2_IN aval:
            result.add(newMove(KNIGHT, sq,sq2,board.determinePieceCapture(sq2)))
    
    #Bishop
    var bishops = board.pieces[BISHOP] & board.colors[act]
    FOR_SQ_IN bishops:
        var aval:BB = bishop_moves(occupied, sq) & capturable
        FOR_SQ2_IN aval:
            result.add(newMove(BISHOP,sq,sq2,board.determinePieceCapture(sq2)))
    
    #Rooks
    var rooks = board.pieces[ROOK] & board.colors[act]
    FOR_SQ_IN rooks:
        var aval:BB = rook_moves(occupied, sq) & capturable
        FOR_SQ2_IN aval:
            result.add(newMove(ROOK, sq,sq2,board.determinePieceCapture(sq2)))
    
    #Queen
    var queens = board.pieces[QUEEN] & board.colors[act]
    FOR_SQ_IN queens:
        var aval:BB = (rook_moves(occupied, sq) | rook_moves(occupied, sq)) & capturable
        FOR_SQ2_IN aval:
            result.add(newMove(QUEEN, sq,sq2,board.determinePieceCapture(sq2)))
    
    #King
    var king = board.pieces[KING] & board.colors[act]
    var sq = king.countTrailingZeroBits
    var aval: BB = KING_MOVES[sq] & capturable
    FOR_SQ2_IN aval:
        result.add(newMove(KING, sq,sq2,board.determinePieceCapture(sq2)))

func make*(board:Board, move:Move):Board = 
    ## Makes a move by a copy. TODO - consider making this a hybrid make-unmake/copy version.
    
    let act = board.activeColor
    result = board
    if move.piece == KING_ROOK: #castling
        var kingMask, rookMask: BB
        if move.to < move.frm:
            kingMask = 0b00010100 << (act * 56)
            rookMask = 0b00001001 << (act * 56)
        else:
            kingMask = 0b01010000 << (act * 56)
            rookMask = 0b10100000 << (act * 56)
        result.colors[act] = result.colors[act] ^ kingMask ^ rookMask
        result.pieces[ROOK] = result.pieces[ROOK] ^ rookMask
        result.pieces[KING] = result.pieces[KING] ^ kingMask
    else:        
        var mask:BB = 1<<move.to
        if move.capturedPiece != NO_PIECE: #capture
            if move.piece == PAWN and move.to == board.enPassant: # en passant
                let sq:Square = move.to + [-8,8][act]
                result.colors[1-act] = result.colors[1-act] ^ (1<<sq)
                result.pieces[PAWN] = result.pieces[PAWN] ^ (1<<sq)
            else:
                result.colors[1-act] = result.colors[1-act] ^ mask
                result.pieces[move.capturedPiece] = result.pieces[move.capturedPiece] ^ mask
        mask = (1<<move.frm) | mask
        result.colors[act] = result.colors[act] ^ mask
        result.pieces[move.piece] = result.pieces[move.piece] ^ mask
    let fromNormalised = move.frm - 56*act # enables us asking universal question, checking if A1 or A8, E1 or E8, H1 or H8 moved
    if fromNormalised == E1:
        result.canCastle[act][0] = false
        result.canCastle[act][1] = false
    elif fromNormalised == A1:
        result.canCastle[act][0] = false
    elif fromNormalised == H1:
        result.canCastle[act][1] = false
        
    #enPassant
    result.enPassant = NO_SQUARE
    if move.piece == PAWN:
        if move.to - move.frm == 16:
            result.enPassant = move.frm + 8
        elif move.to - move.frm == -16:
            result.enPassant = move.frm - 8
    
    #promotion
    if move.promotion != NO_PIECE:
        var mask:BB = 1<<move.to
        result.pieces[PAWN] = result.pieces[PAWN] ^ mask
        result.pieces[move.promotion] = result.pieces[move.promotion] ^ mask
    
    let king:Square = countTrailingZeroBits(result.colors[1 - act] & result.pieces[KING])
    result.isCheck = result.isAttacked(king, act)
    
    if move.capturedPiece == NO_PIECE and move.promotion == NO_PIECE:
        result.move50 += 1
    else:
        result.move50 = 0
    
    result.active_color = 1 - act

func isLegal*(position:Board): bool =
    ## Determines if `position` is legal, that is if activeColor doesn't attack opponent's king.
    
    let king:Square = countTrailingZeroBits(position.colors[1-position.activeColor] & position.pieces[KING])
    return not position.isAttacked(king, position.activeColor)

func genSons*(father:Board): seq[(Move,Board)] = 
    ## Generates all legal moves and resulting positions.
    
    let moves = genPseudoMoves(father)
    for move in moves:
        let son = father.make(move)
        if son.isLegal:
            result.add((move,son))

func genQuiescenceSons*(father:Board): seq[(Move,Board)] = 
    ## Generates all legal quiescence moves and resulting positions.
    
    let moves = genPseudoQuiescenceMoves(father)
    for move in moves:
        let son = father.make(move)
        if son.isLegal:
            result.add((move,son))

func moveExists*(board:Board):bool =
    ## Determines whether a legal move exists.
    
    var act = board.activeColor
    var notMine = not board.colors[act]
    var free = board.free
    var occupied = board.occupied
    var capturable = board.colors[1-act]
    var capturableP = capturable | (1<<board.enPassant)
    
    #King
    var king = board.pieces[KING] & board.colors[act]
    var sq = king.countTrailingZeroBits
    var aval: BB = KING_MOVES[sq] & notMine
    FOR_SQ2_IN aval:
        var move = newMove(KING, sq,sq2,board.determinePieceCapture(sq2))
        if board.make(move).isLegal:
            return true
    
    #Queen
    var queens = board.pieces[QUEEN] & board.colors[act]
    FOR_SQ_IN queens:
        var aval:BB = (bishop_moves(occupied, sq) | rook_moves(occupied, sq)) & notMine
        FOR_SQ2_IN aval:
            var move = newMove(QUEEN, sq,sq2,board.determinePieceCapture(sq2))
            if board.make(move).isLegal:
                return true
    
    #Knight
    var knights = board.pieces[KNIGHT] & board.colors[act]
    FOR_SQ_IN knights:
        var aval: BB = KNIGHT_MOVES[sq] & notMine
        FOR_SQ2_IN aval:
            var move = newMove(KNIGHT, sq,sq2,board.determinePieceCapture(sq2))
            if board.make(move).isLegal:
                return true
    
    #Bishop
    var bishops = board.pieces[BISHOP] & board.colors[act]
    FOR_SQ_IN bishops:
        var aval:BB = bishop_moves(occupied, sq) & notMine
        FOR_SQ2_IN aval:
            var move = newMove(BISHOP, sq,sq2,board.determinePieceCapture(sq2))
            if board.make(move).isLegal:
                return true
    
    #Rooks
    var rooks = board.pieces[ROOK] & board.colors[act]
    FOR_SQ_IN rooks:
        var aval:BB = rook_moves(occupied, sq) & notMine
        FOR_SQ2_IN aval:
            var move = newMove(ROOK, sq,sq2,board.determinePieceCapture(sq2))
            if board.make(move).isLegal:
                return true
    
    #Pawns
    let myPawns = board.pieces[PAWN] & board.colors[act]
    var pawns1 = myPawns
    if act == WHITE:
        var leftCapture = myPawns & 0x00_fe_fe_fe_fe_fe_fe_00 & (capturableP >> 7)
        FOR_SQ_IN leftCapture:
            let captured = board.determinePieceCapture(sq+7)                    
            let move = newMove(PAWN, sq,sq+7,captured)
            if board.make(move).isLegal:
                return true
        var rightCapture = myPawns & 0x00_7f_7f_7f_7f_7f_7f_00 & (capturableP >> 9)
        FOR_SQ_IN rightCapture:
            let captured = board.determinePieceCapture(sq+9)                    
            let move = newMove(PAWN, sq,sq+9,captured)
            if board.make(move).isLegal:
                return true
        pawns1 = pawns1 & (free>>8) & 0x00_ff_ff_ff_ff_ff_ff_00 # pawns that can push 1 square
        var pawns2 = pawns1 & (free >> 16) & 0x00_00_00_00_00_00_ff_00 #pawns that can push 2 squares
        FOR_SQ_IN pawns1:
            let move = newMove(PAWN, sq,sq+8,NO_PIECE)
            if board.make(move).isLegal:
                return true
        FOR_SQ_IN pawns2:
            let move = newMove(PAWN, sq, sq+16,NO_PIECE)
            if board.make(move).isLegal:
                return true
    else:
        var leftCapture = myPawns & 0x00_fe_fe_fe_fe_fe_fe_00 & (capturableP << 9)
        FOR_SQ_IN leftCapture:
            let captured = board.determinePieceCapture(sq-9)                    
            let move = newMove(PAWN, sq,sq-9,captured)
            if board.make(move).isLegal:
                return true              
        var rightCapture = myPawns & 0x00_7f_7f_7f_7f_7f_7f_00 & (capturableP << 7)
        FOR_SQ_IN rightCapture:
            let captured = board.determinePieceCapture(sq-7)                    
            let move = newMove(PAWN, sq,sq-7,captured)
            if board.make(move).isLegal:
                return true
        pawns1 = pawns1 & (free<<8) & 0x00_ff_ff_ff_ff_ff_ff_00 # pawns that can push 1 square
        var pawns2 = pawns1 & (free << 16) & 0x00_ff_00_00_00_00_00_00 #pawns that can push 2 squares
        FOR_SQ_IN pawns1:
            let move = newMove(PAWN, sq,sq-8,NO_PIECE)
            if board.make(move).isLegal:
                return true
        FOR_SQ_IN pawns2:
            let move = newMove(PAWN, sq,sq-16,NO_PIECE)
            if board.make(move).isLegal:
                return true
    
    return false


func isMate*(board:Board): bool =
    ## Determines if position is a mate (checkmate or stalemate). Alias for `not moveExists`.
    not board.moveExists

func isStalemate*(board:Board): bool =
    ## Determines if position is a stalemate.
    board.isMate and not board.isCheck

func isCheckmate*(board:Board): bool = 
    ## Determines if a position is a checkmate.
    board.isCheck and board.isMate

func toAlgebraic*(board:Board, m:Move): string =
    ## Returns a (position dependant) string representation of a move in a standard (PGN) algebraic notation.
    if m.piece == UNDO_MOVE:
        return "undoing two plies"
    if m.piece == KING_ROOK:
        if m.to > m.frm:
            return "O-O"
        else:
            return "O-O-O"
    if m.piece != PAWN:
        result &= $m.piece
    var sons = board.genSons.filterIt(it[0].piece == m.piece and it[0].to == m.to)
    if m.piece == PAWN:
        if m.capturedPiece != NO_PIECE:
            result &= ($m.frm)[0]
    elif sons.len > 1:
        var sonsF = sons.filterIt(it[0].frm mod 8 == m.frm mod 8)
        var sonsR = sons.filterIt(it[0].frm div 8 == m.frm div 8)
        if sonsF.len == 1:
            result &= ($m.frm)[0]
        elif sonsR.len == 1:
            result &= ($m.frm)[1]
        else:
            result &= $m.frm
    if m.capturedPiece != NO_PIECE:
        result &= "x"
    result &= $m.to
    if m.promotion != NO_PIECE:
        result &= "=" & $m.promotion
    if board.make(m).isCheck:
        result &= "+"

func parseAlgebraic*(board:Board, m:string): Move =
    ## Parses a move from an algebraic notation. Does so by generating Alg. notations for all legal moves and comparing it.
    ## Therefore `m` must take a form `board.toAlgebraic(move)` where `board.fromAlgebraic(m) == move`.
    ## If `m` doesn't match any legal move, `Move(piece:NULL_MOVE)` is returned.
    
    if m == "undo":
        return Move(piece: UNDO_MOVE)
    for (move, son) in board.genSons:
        if board.toAlgebraic(move) == m:
            return move
    return Move(piece: NULL_MOVE)

when isMainModule:
    while true:
        echo "FEN?"
        var position = FEN2board(stdin.readLine)
        showInBrowser(position)
        for (move, son) in position.genSons:
            echo position.toAlgebraic(move)

