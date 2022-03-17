## Static evaluation of a position.

import strutils, bitops
import board, movegen, templates

const CHECKMATE_SCORE* = 20000
const CHECKMATE_BOUND* = 19000

#TODO mobility bonus/penalty
func `++`(st:array[64, int], el:int):array[64, int] {.compileTime.} = 
    for i in 0..63:
        result[i] = st[i] + el

const BLACK_PAWN_ST = [
 0,  0,  0,  0,  0,  0,  0,  0,
50, 50, 50, 50, 50, 50, 50, 50,
10, 10, 20, 30, 30, 20, 10, 10,
 5,  5, 10, 25, 25, 10,  5,  5,
 0,  0,  0, 20, 20,  0,  0,  0,
 5, -5,-10,  0,  0,-10, -5,  5,
 5, 10, 10,-20,-20, 10, 10,  5,
 0,  0,  0,  0,  0,  0,  0,  0] ++ 100
 
const BLACK_KNIGHT_ST = [
-50,-40,-30,-30,-30,-30,-40,-50,
-40,-20,  0,  0,  0,  0,-20,-40,
-30,  0, 10, 15, 15, 10,  0,-30,
-30,  5, 15, 20, 20, 15,  5,-30,
-30,  0, 15, 20, 20, 15,  0,-30,
-30,  5, 10, 15, 15, 10,  5,-30,
-40,-20,  0,  5,  5,  0,-20,-40,
-50,-40,-30,-30,-30,-30,-40,-50,] ++ 320

const BLACK_BISHOP_ST = [
-20,-10,-10,-10,-10,-10,-10,-20,
-10,  0,  0,  0,  0,  0,  0,-10,
-10,  0,  5, 10, 10,  5,  0,-10,
-10,  5,  5, 10, 10,  5,  5,-10,
-10,  0, 10, 10, 10, 10,  0,-10,
-10, 10, 10, 10, 10, 10, 10,-10,
-10,  5,  0,  0,  0,  0,  5,-10,
-20,-10,-10,-10,-10,-10,-10,-20] ++ 330

const BLACK_ROOK_ST = [
  0,  0,  0,  0,  0,  0,  0,  0,
  5, 10, 10, 10, 10, 10, 10,  5,
 -5,  0,  0,  0,  0,  0,  0, -5,
 -5,  0,  0,  0,  0,  0,  0, -5,
 -5,  0,  0,  0,  0,  0,  0, -5,
 -5,  0,  0,  0,  0,  0,  0, -5,
 -5,  0,  0,  0,  0,  0,  0, -5,
 -1,  0,  0,  5,  5,  0,  0,  -1] ++ 500
  
const BLACK_QUEEN_ST = [
-20,-10,-10, -5, -5,-10,-10,-20,
-10,  0,  0,  0,  0,  0,  0,-10,
-10,  0,  5,  5,  5,  5,  0,-10,
 -5,  0,  5,  5,  5,  5,  0, -5,
  0,  0,  5,  5,  5,  5,  0, -5,
-10,  0,  5,  5,  5,  5,  5,-10,
-10,  0,  0,  0,  0,  5,  0,-10,
-20,-10,-10, -5, -5,-10,-10,-20] ++ 900

const BLACK_KING_MG_ST = [
-30,-40,-40,-50,-50,-40,-40,-30,
-30,-40,-40,-50,-50,-40,-40,-30,
-30,-40,-40,-50,-50,-40,-40,-30,
-30,-40,-40,-50,-50,-40,-40,-30,
-20,-30,-30,-40,-40,-30,-30,-20,
-10,-20,-20,-20,-20,-20,-20,-10,
 20, 20,  0,  0,  0,  0, 20, 20,
 20, 30, 10,  0,  0, 10, 30, 20]
 
const BLACK_KING_EG_ST = [
-50,-40,-30,-20,-20,-30,-40,-50,
-30,-20,-10,  0,  0,-10,-20,-30,
-30,-10, 20, 30, 30, 20,-10,-30,
-30,-10, 30, 40, 40, 30,-10,-30,
-30,-10, 30, 40, 40, 30,-10,-30,
-30,-10, 20, 30, 30, 20,-10,-30,
-30,-30,  0,  0,  0,  0,-30,-30,
-50,-30,-30,-30,-30,-30,-30,-50]

func rev(st:array[64, int]):array[64, int] {.compileTime.} = 
    for y in 0..7:
        for x in 0..7:
            result[8*y+x] = st[(7-y)*8+x]


const PIECE_SQUARE_TABLE = [
    [
        [BLACK_PAWN_ST.rev, BLACK_KNIGHT_ST.rev, BLACK_BISHOP_ST.rev, BLACK_ROOK_ST.rev, BLACK_QUEEN_ST.rev, BLACK_KING_MG_ST.rev],
        [BLACK_PAWN_ST, BLACK_KNIGHT_ST, BLACK_BISHOP_ST, BLACK_ROOK_ST, BLACK_QUEEN_ST, BLACK_KING_MG_ST]
    ],
    [
        [BLACK_PAWN_ST.rev, BLACK_KNIGHT_ST.rev, BLACK_BISHOP_ST.rev, BLACK_ROOK_ST.rev, BLACK_QUEEN_ST.rev, BLACK_KING_EG_ST.rev],
        [BLACK_PAWN_ST, BLACK_KNIGHT_ST, BLACK_BISHOP_ST, BLACK_ROOK_ST, BLACK_QUEEN_ST, BLACK_KING_EG_ST]
    ]
]

func abs(a:int):int =
    (if a > 0: a else: -a)

func rookVsKingEval*(board: Board): int =
    ## In the KRK endgame, evaluates the position based on how much roaming space the losing king has and
    ## the distance between the kings.
    
    result = 10000
    var losingColor = WHITE
    if (board.pieces[ROOK] & board.white) != 0:
        losingColor = BLACK
    let losingKing:Square = countTrailingZeroBits(board.pieces[KING] & board.colors[losingColor])
    let winningKing:Square = countTrailingZeroBits(board.pieces[KING] & board.colors[1-losingColor])
    let rook = countTrailingZeroBits(board.pieces[ROOK])
    var rookX, rookY, kingX, kingY, kingWIdth, kingHeight: int
    (rookX, rookY) = (rook mod 8, rook div 8)
    (kingX, kingY) = (losingKing mod 8, losingKing div 8)
    if rookX > kingX:
        kingWidth = rookX
    else:
        kingWidth = 7 - rookX
    if rookY > kingY:
        kingHeight = rookY
    else:
        kingHeight = 7 - rookY
    result += (49 - kingWidth*kingHeight) * 10
    result += (abs(kingX - winningKing mod 8) + abs(kingY - winningKing div 8)).int
    if losingColor == WHITE:
        result *= -1

func pieceImprovement*(piece: Piece, frm, to: Square, color: Color): int =
    ## Determines a noncapture piece improvement when moving from `frm` to `to` for the purpose of move ordering.
    ## Castling has a bonus.
    if piece == KING_ROOK:
        return 200
    return PIECE_SQUARE_TABLE[0][color][piece][to] - PIECE_SQUARE_TABLE[0][color][piece][frm]

func eval_piece*(board: Board, phase: int, color: Color, piece: Piece): int {.inline.} =
    ## Calculates the evaluation over all piece of a given color and given type.
    
    var piecesLeft = board.colors[color] & board.pieces[piece]
    FOR_SQ_IN piecesLeft:
        result += PIECE_SQUARE_TABLE[phase][color][piece][sq]

func eval_pawns*(board:Board, color:Color): int {.inline.} = 
    ## Calculates the evaluation of pawns. This piece type is special,
    ## since we consider the pawn structure too.
    ## TODO: give bonus to pawn chains.
    ## TODO: give bonus to king shelter (maybe in king func)
    var pawnsLeft = board.colors[color] & board.pieces[PAWN]
    var occColumns: array[8, bool]
    FOR_SQ_IN pawnsLeft:
        let column = sq mod 8
        result += PIECE_SQUARE_TABLE[0][color][PAWN][sq]
        if occColumns[column]:
            result -= 40 #doubled pawns = bad
        occColumns[column] = true

func eval_king*(board:Board, phase: int, color:Color): int {.inline.} =
    ## Calculates the evaluation of king.
    ## TODO penalty for destroying castling rights?
    let myKing =  board.pieces[KING] & board.colors[color]
    let myRooks = board.pieces[ROOK] & board.colors[color]
    
    if color == WHITE:
        if ((myKing & (F1|G1) and myRooks & (G1|H1)) | (myKing & (B1|C1) and myRooks & (A1|B1))) != 0:
            result -= 120
    else:
        if ((myKing & (F8|G8) and myRooks & (G8|H8)) | (myKing & (B8|C8) and myRooks & (A8|B8))) != 0:
            result -= 120
    result += PIECE_SQUARE_TABLE[phase][color][KING][myKing.countTrailingZeroBits]    

func eval_mg*(board: Board): int {.inline.} = 
    ## Evaluate the aspects that depend on gameProgress, as if it was middlegame.
    return eval_king(board, 0, WHITE) - eval_king(board, 0, BLACK)

func eval_eg*(board: Board): int {.inline.} =
    ## Evaluate the aspects that depend on gameProgress, as if it was endgame.
    return eval_king(board, 1, WHITE) - eval_king(board, 1, BLACK)

func eval_unif*(board: Board): int {.inline.} =
    ## Evaluates the aspects that don't depend on game progress.
    return eval_pawns(board, WHITE)  - eval_pawns(board, BLACK) +
    eval_piece(board, 1, WHITE, KNIGHT) - eval_piece(board, 1, BLACK, KNIGHT) + 
    eval_piece(board, 1, WHITE, BISHOP) - eval_piece(board, 1, BLACK, BISHOP) + 
    eval_piece(board, 1, WHITE, ROOK)   - eval_piece(board, 1, BLACK, ROOK) +
    eval_piece(board, 1, WHITE, QUEEN)  - eval_piece(board, 1, BLACK, QUEEN)

func count_material*(board: Board): int =
    ## Counts material for the purpose of game phase in time management.
    result += popcount(board.pieces[PAWN]) mod 2
    result += popcount(board.pieces[KNIGHT] | board.pieces[BISHOP]) * 3
    result += popcount(board.pieces[ROOK]) * 5
    result += popcount(board.pieces[QUEEN]) * 15

proc eval*(board: Board, history: array[512, Board], ply: int, depth:int): int = 
    ## Evaluates the positions including cecking for draws by stalemate and 3fold repetition.
    ## Actually even a 2fold repetition is considerd a draw (there's no disadvantage in that).
    for i in countup(4, 1000, 2):
        if ply-i < 0:
            break
        if board == history[ply-i]:
            return 0
    
    var gameProgress: int = popcount(board.pieces[KNIGHT] | board.pieces[BISHOP]) * 3
    gameProgress         += popcount(board.pieces[ROOK]) * 5
    gameProgress         += popcount(board.pieces[QUEEN]) * 15
    gameProgress = 256 - gameProgress * 256 div (8 * 3 + 4*5 + 2*15)
    if board.isCheck:
        if board.isMate:
            return -CHECKMATE_SCORE+depth
    else:
        if gameProgress > 128 and board.isMate: #in endgame we actually need to check if there are possible moves
            return 0
    if gameProgress > 235 and popcount(board.occupied) == 3 and board.pieces[ROOK] != 0:
            result = rookVsKingEval(board)
    else:
        var gP = gameProgress
        if gp < 150:
            gp = 80
        result = eval_unif(board) + (eval_mg(board) * (256 - gameProgress) + gameProgress * eval_eg(board)) div 256
    if board.activeColor == BLACK:
        result *= -1

func evalAprox*(board: Board): int =
    ## TODO: fast approximation of a evaluation.
    ## Perhaps only using popcounts and piece values independent of squares.
    ## Perhaps this could be used in a more sophisticated search scheme.
    return 0 #TODO

func formatScore*(board:Board, score: int): string =
    ## Formats the score for printing. Negamax type of score is converted to objective values,
    ## value is converted from centipawns to pawns and forced mate scores are displayed as full moves until mate.
    ## Further more if a score was not calculated at all (perhaps there was only a single root move),
    ## "?" is returned.
    
    var score2 = score
    if score == -99999: #TODO this might not be  a constant per se
        return "?"
    if board.activeColor == BLACK:
        score2 *= -1
    if score2 < 0:
        result &= "-"
        score2 *= -1
    if score2 > CHECKMATE_BOUND:
        result &= "#" & $((CHECKMATE_SCORE - score2+1) div 2)
        result = result.replace("-#", "#-")
    else:
        result &= $(score2 div 100) & "." & $(score2 div 10 mod 10) & $(score2 mod 10)
    #result &= "(" & $score & ")"
    
when isMainModule:
    var position = FEN2board(CHESS_STARTING_FEN)
    while true:
        showInBrowser position
        echo position.eval(0)
        echo "FEN?"
        var line = stdin.readLine
        if line == "":
            break
        position = FEN2board(line)