## This file defines, Squares, pieces, boards and related functions.

import bitops, sequtils, strutils, browsers, os, random
randomize()

# Bitboard and Square types
# 0. bit = a1, 1. bit = a2, 63. bit = h8
type BB* = int64 ## Bitboard - 0. bit = a1, 1. bit = a2, 63. bit = h8

type Square* = range[-1..63] ## Square - values: NO_SQUARE, A1, ..., H8

# Bit operations are common, we want to use common operators
# TODO: inplace versions
func `&`*(a, b: BB): BB = a and b           ## And with common & operator.
func `^`*(a, b: BB): BB = a xor b           ## Xor with common ^ operator.
func `|`*(a, b: BB): BB = a or b            ## Or with common | operator.
func `>>`*(a: BB; b: Square): BB = a shr b  ## Right shift with common & operator.    
func `<<`*(a: BB; b: Square): BB = a shl b  ## Left shift with common & operator.

#TODO - turn this into a macro
const NO_SQUARE*:Square = -1
const A1*:Square = 0;const B1*:Square = 1;const C1*:Square = 2;const D1*:Square = 3;const E1*:Square = 4;const F1*:Square = 5;const G1*:Square = 6;const H1*:Square = 7;const A2*:Square = 8;const B2*:Square = 9;const C2*:Square = 10;const D2*:Square = 11;const E2*:Square = 12;const F2*:Square = 13;const G2*:Square = 14;const H2*:Square = 15;const A3*:Square = 16;const B3*:Square = 17;const C3*:Square = 18;const D3*:Square = 19;const E3*:Square = 20;const F3*:Square = 21;const G3*:Square = 22;const H3*:Square = 23;const A4*:Square = 24;const B4*:Square = 25;const C4*:Square = 26;const D4*:Square = 27;const E4*:Square = 28;const F4*:Square = 29;const G4*:Square = 30;const H4*:Square = 31;const A5*:Square = 32;const B5*:Square = 33;const C5*:Square = 34;const D5*:Square = 35;const E5*:Square = 36;const F5*:Square = 37;const G5*:Square = 38;const H5*:Square = 39;const A6*:Square = 40;const B6*:Square = 41;const C6*:Square = 42;const D6*:Square = 43;const E6*:Square = 44;const F6*:Square = 45;const G6*:Square = 46;const H6*:Square = 47;const A7*:Square = 48;const B7*:Square = 49;const C7*:Square = 50;const D7*:Square = 51;const E7*:Square = 52;const F7*:Square = 53;const G7*:Square = 54;const H7*:Square = 55;const A8*:Square = 56;const B8*:Square = 57;const C8*:Square = 58;const D8*:Square = 59;const E8*:Square = 60;const F8*:Square = 61;const G8*:Square = 62;const H8*:Square = 63


# Type and constants for pieces color and type
type Color* = range[0..1] ## Color type - values: WHITE, BLACK
const WHITE*: Color = 0
const BLACK*: Color = 1
type Piece* = range[-1..8] ## Piece type - values: NO_PIECE, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING, KING_ROOK, UNDO_MOVE, NULL_MOVE
const
    NO_PIECE*:  Piece = -1
    PAWN*:      Piece = 0
    KNIGHT*:    Piece = 1
    BISHOP*:    Piece = 2
    ROOK*:      Piece = 3
    QUEEN*:     Piece = 4
    KING*:      Piece = 5
    KING_ROOK*: Piece = 6 #Castle
    UNDO_MOVE*: Piece = 7 #Undo move
    NULL_MOVE*: Piece = 8 #Null move #TODO not used anywhere

const PIECES_LETTERS = "pnbrqkc"
const PIECES_UNICODE = ["♙","♘","♗","♖","♕","♔","♟︎","♞","♝","♜","♛","♚"]

const UNIVERSE*: BB = 0xffffffffffffffff ## Universe (full) bitboard
const EMPTY*: BB = 0 ## Empty bitboard

type
    Board* = object
        ## Board type
        colors*: array[2, BB]                   ## BBs for white and black pieces
        pieces*: array[6, BB]                   ## BBs for pawns, knights, bishops, rooks, queens, kings
        activeColor*: Color                     ## active color
        canCastle*: array[2, array[2, bool]]    ## castling rights for white, black; queen side, king side
        isCheck*: bool                          ## is current player in check?
        enPassant*: Square                      ## target Square for en_passant (0 denotes none or idk maybe extend to range to -1)
        move50*: int                            ## ply counter since irreversible move

const CHESS_STARTING_FEN* = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 0" ## \
## FEN of starting chess position. This is equivalent to `id2FEN(518)` (except for castling rights, which are TODO).

#Convenience functions for white, black, free, occupied bitboards
func white*(board: Board): BB {.inline.} = board.colors[WHITE]
func black*(board: Board): BB {.inline.} = board.colors[BLACK]
func occupied*(board: Board): BB {.inline.} = board.white | board.black
func free*(board: Board): BB {.inline.} = not(board.white ^ board.black)

func `$`*(piece: Piece): string = 
    ## Converts a piece in `PAWN..KING` to a single letter representation.
    toUpper(PIECES_LETTERS[piece] & "")

func `$$`*(bb: BB): string =
    ## Generates ASCII version of the BB, for debugging purposes. I think that single $ doesn't work, it doesn't override `$(int64)`.
    for y in 0..7:
        for x in 0..7:
            var sq:BB = BB(8*(7-y) + x)
            if bb.testBit(sq):
                result &= "#"
            else:
                result &= "."            
            if sq mod 8 == 7:
                result &= "\n"

func parseSquare*(s: string): Square =
    ## Parses a string representation of a square. `"-"` (as is used in FEN) maps to `NO_SQUARE`.
    if s == "-":
        return NO_SQUARE
    Square(s[0].int - 'a'.int + (s[1].int - '1'.int) * 8)

func `$`*(sq: Square): string = 
    ## Returns a string representation of a square. `NO_SQUARE` maps to `"-"` (as is used in FEN).
    if sq == NO_SQUARE:
        return "-"
    var x = sq mod 8
    var y = sq div 8 + 1
    "abcdefgh"[x] & $y

func determinePiece*(board:Board, sq:Square): Piece {.inline.} =
    ## Determines what piece is on the square. If the square is empty, `NO_PIECE` is returned.    
    let mask:BB = 1<<sq
    for piece in PAWN..KING:
        if board.pieces[piece] & mask != 0:
            return piece
    return NO_PIECE

func determinePieceCapture*(board:Board, sq:Square): Piece {.inline.} =
    ## Determines what piece is being captured on square sq. That is if sq is en passant target, `PAWN` is returned.
    ## Furhermore, we assume that the piece is not king, so we can exit the loop one iteration earlier.    
    if sq == board.enPassant:
        return PAWN
    let mask:BB = 1<<sq
    for piece in PAWN..QUEEN:
        if board.pieces[piece] & mask != 0:
            return piece
    return NO_PIECE

func id960FEN*(N:int): string =
    ## Creates FEN starting position from its 960 id.
    
    var pieces = "--------"
    var ranks = toSeq(0..7)
    var N2 = N div 4; var B1 = N mod 4
    pieces[2*B1 + 1] = 'B'
    ranks.keepItIf(it != 2*B1 + 1)
    var N3 = N2 div 4; var B2 = N2 mod 4
    pieces[2*B2] = 'B'
    ranks.keepItIf(it != 2*B2)
    var N4 = N3 div 6; var Q = N3 mod 6
    pieces[ranks[Q]] = 'Q'
    ranks.keepItIf(it != ranks[Q])
    var knight1 = 0
    var knight2 = N4 + 1
    if N4 > 3:
        knight1 = 1
        knight2 = N4 - 2
    if N4 > 6:
        knight1 = 2
        knight2 = N4 - 4
    if N4 > 8:
        knight1 = 3
        knight2 = 4
    pieces[ranks[knight1]] = 'N'
    pieces[ranks[knight2]] = 'N'
    ranks.keepItIf(it != ranks[knight1] and it != ranks[knight2])
    pieces[ranks[0]] = 'R'
    pieces[ranks[1]] = 'K'
    pieces[ranks[2]] = 'R'
    return pieces.toLower & "/pppppppp/8/8/8/8/PPPPPPPP/" & pieces & " w - - 0 1"


proc FEN2board*(FEN: string): Board = 
    ## Loads a board from FEN format.
    
    var parts = FEN.split(" ")
    var x, y: int
    y = 7
    for chr in parts[0]:
        if chr == '/':
            x = 0
            y -= 1
            continue
        if chr.isDigit:
            x += parseInt(chr & "")
            continue
        if chr in PIECES_LETTERS:
            result.colors[BLACK].setBit(y*8 + x)
        else:
            result.colors[WHITE].setBit(y*8 + x)
        var chr2 = toLower(chr & "")[0]
        for pc in PAWN..KING:
            if chr2 == PIECES_LETTERS[pc]:
                result.pieces[pc].setBit(y*8 + x)
        x += 1
    if parts[1] == "b":
        result.activeColor = BLACK
    
    result.canCastle[WHITE][0] = 'Q' in parts[2]
    result.canCastle[WHITE][1] = 'K' in parts[2]
    result.canCastle[BLACK][0] = 'q' in parts[2]
    result.canCastle[BLACK][1] = 'k' in parts[2]
    
    result.enPassant = parseSquare(parts[3])
    
    #TODO move50, moves counter
    
    #TODO calculate isCheck:
    #let king:Square = countTrailingZeroBits(result.colors[activeColor] & result.pieces[KING])
    #result.isCheck = result.isAttacked(king, 1-activeColor)

proc cleanFEN*(FEN: string): string =
    ## Cleans a FEN. That is, converts empty string to default chess starting FEN, and interprets numbers
    ## as chess 960 positions, where 960 indicates random position.
    if FEN == "":
        return CHESS_STARTING_FEN
    if FEN.len <= 3:
        var N = FEN.parseInt
        N = if N == 960: rand(960) else: N
        return id960FEN(N)
    return FEN    

func FEN*(board:Board): string = 
    ## Generates a FEN representation of the board.
    
    for y in countdown(7,0):
        var emptyCount = 0
        for x in 0..7:
            var sq:BB = BB(8*y + x)
            var chr = ""
            if board.occupied.testBit(sq):
                if emptyCount > 0:
                    result &= $emptyCount
                    emptyCount = 0
                for pc in PAWN..KING:
                    if board.pieces[pc].testBit(sq):
                        chr &= PIECES_LETTERS[pc]
                if board.white.testBit(sq):
                    chr = chr.toUpper()
                result &= chr
            else:
                emptyCount += 1
        if emptyCount > 0:
            result &= $emptyCount
            emptyCount = 0
        if y != 0:
            result &= "/"
    result &= (if board.activeColor == BLACK: " b " else: " w ")
    let castlingSymbols = "QKqk"
    var castling = ""
    for c in WHITE..BLACK:
        for s in 0..1:
            if board.canCastle[c][s]:
                castling &= castlingSymbols[c*2 + s]
    if castling == "":
        castling = "-"
    result &= castling
    if board.enPassant == NO_SQUARE:
        result &= " - "
    else:
        result &= " " & $board.enPassant & " "
    result &= $board.move50 & " ?"
                
func `==`*(a,b: Board): bool = 
    ## Tests two boards for equivality.
    ## Compares most likeli different terms first.
    ## TODO compare hash first
    a.colors == b.colors and a.pieces == b.pieces #TODO check enPassant and castle rights

func `$`*(board: Board): string = 
    ## Generates ASCII representation of a board (for debugging purposes.
    
    for y in countdown(7,0):
        result &= $(y+1) & " "
        for x in 0..7:
            var sq:BB = BB(8*y + x)
            var chr = ""
            if board.occupied.testBit(sq):
                for pc in PAWN..KING:
                    if board.pieces[pc].testBit(sq):
                        chr &= PIECES_LETTERS[pc]
                if board.white.testBit(sq):
                    chr = chr.toUpper()
            else:
                chr = "."
            result &= chr
        result &= "\n"
    result &= "\n  ABCDEFGH\n"

func debugBoard*(board: Board): string = 
    ## Generates ASCII representation of the internal variables comprising the board (for debugging).
    result &= "White:\n"    & $$board.white
    result &= "\nBlack:\n"  & $$board.black
    result &= "\nPawns:\n"  & $$board.pieces[PAWN]
    result &= "\nKnight:\n" & $$board.pieces[KNIGHT]
    result &= "\nBishop:\n" & $$board.pieces[BISHOP]
    result &= "\nRook:\n"   & $$board.pieces[ROOK]
    result &= "\nQueen:\n"  & $$board.pieces[QUEEN]
    result &= "\nKing:\n"   & $$board.pieces[KING]

func htmlRepr*(board: Board, comment:string): string = 
    ## Generates a HTML page displaying the board provided.
    ## The page automatically refreshes itself so it can be used as realtime board display -
    ## for debugging and for playing too.
    ## Extra text `comment` can be appended below the board.
    result = """<!DOCTYPE html>
<head>
  <meta charset="UTF-8" />
  <title>Chessboard viewer</title>
  <script>
  setTimeout(function(){location.reload();}, 500);  
  </script>
  <style>
  body, table, td{
    border-collapse: collapse;
    margin: 0px;
    padding: 0px
  table-layout: fixed;
  }
  td{
    width: 12.5vmin;
    height: 12.5vmin;
    text-align: center;
    font-size: 9vmin;
    position: relative;
  }
  .b{
    background-color: lightgray;
  }
  td span{
    position: absolute;
    font-size: 2vmin;
    color: gray;
    left: 0px;
    top: 0px;
  }
  </style>
</head>
<body>
<table>"""
    for y in countdown(7,0):
        result &= "<tr>"
        for x in 0..7:
            if (x+y) mod 2 == 0:                
                result &= "<td class='b'>"
            else:
                result &= "<td class='w'>"
            var sq = 8*y + x
            result &= "<span>" & $Square(sq) & "</span>"
            if board.occupied.testBit(sq):
                for pc in PAWN..KING:
                    if board.pieces[pc].testBit(sq):
                        result &= PIECES_UNICODE[pc + 6*board.black.testBit(sq).int] 
            result &= "</td>"
        result &= "</tr>"
        
    result &= "</table>"
    result &= "\n<br>\n<pre>" & comment
    result &= "</pre></body></html>"
    #TODO output game state

proc showInBrowser*(position:Board, comment:string) =
    ## Writes the board representation to a HTML file.
    writeFile("board_view.html", position.htmlRepr(comment))

proc showInBrowser*(position:Board) =
    ## Writes the board representation to a HTML file using an empty comment string.
    showInBrowser(position, position.FEN)
            


#TODO Zobrist hashing
#WEB: https://sites.google.com/site/tscpchess/make-move
# https://webdocs.cs.ualberta.ca/~jonathan/PREVIOUS/Courses/657/Notes/5.IDandMO.pdf
        

when isMainModule:
    var board = FEN2board(CHESS_STARTING_FEN)
    showInBrowser(board)

    while true:
        echo "Enter FEN, end with empty line"
        showInBrowser stdin.readLine.cleanFEN.FEN2board

#change var to let where applicable

