# Nimbochromis
This projects attempts to create a chess engine from scratch. My goal is to create an engine that would be able to consistently beat me.  
In the process I'd like to learn Nim and chess programming fundamentals.

Nimbochromis is a genus of African fish. Because of the tradition of naming chess engines after fishes we decided to name the engine after this fish whose name starts with "Nim".

You can play nimbochromis on [lichess.org](https://lichess.org/@/nimbochromis) when it's online.

## Engine design choices
Most of the tricks used come from [Chess programming wiki](chessprogramming.org).  
I want to focus on very fast (pseudolegal) move generation and simple evaluation function.
Might goal is to find a balance between short nice and simple code and execution speed.  
If an ugly code is produced for performance reasons, I should try to shift the uglyness into a macro.

### Board representation
Each position is represented by 8 bitboards: 2 for colors and 6 for each piece type. In addition there are fields for active color, castling rights, en passant square etc. are.
* [Bitboards](https://www.chessprogramming.org/Bitboards)  

### Move generation
Engine generates legal moves by generating pseudolegal moves, making them and checking if a king can be captured. Move generation of sliding pieces work ray by ray using precomputed ray bitboards. Nonsliding pieces use precalucalted bitboards directly.
* [Ray attacks using bitboards](https://www.chessprogramming.org/Classical_Approach)

### Searching
Engine uses an iterative deepening framework, prior to starting a deeper search we estimate if its feasible to finish the deeper search in a desired time.  
PV from the previous iteration is (TODO) used for move ordering in the next one. Moves are ordered based on simple heuristics.
* [Quiescence search](https://www.chessprogramming.org/Quiescence_Search)
* [Principal variation search](https://www.chessprogramming.org/Principal_Variation_Search)
* [Iterative deepening](https://www.chessprogramming.org/Iterative_Deepening)
* [Transposition table](https://www.chessprogramming.org/Transposition_Table)
* [Move ordering](https://www.chessprogramming.org/Move_Ordering)
* [Move generation](https://www.chessprogramming.org/Move_Generation)

### Static evaluation
* [Evaluation function](https://www.chessprogramming.org/Simplified_Evaluation_Function)
* [Piece square tables](https://www.chessprogramming.org/Piece-Square_Tables)

## User manual
The main target of this project is a [lichess BOT](https://lichess.org/@/nimbochromis).
A chess game can can also be played offline by running the "chess.exe". The program will ask you to enter the starting position (empty line = normal chess starting position). Instead of a FEN you can enter a number 0..959 to play a chess 960 game or you can enter 960 to play a random 960 game. (960 is not quite finished - you won't be able to castle in thse games.) Then, you will be asked to choose who will play. Computer vs Computer, Human vs Computer and Human vs Human variants are available. Finally the thinking time for a computer player should be set.
After a game starts you can see the board by opening the file "board_view.html" in your web browser. To enter a move you must type it in the console in the algebraic move notation. You can also type "undo" to move 2 plies back (that is - undo the opponent's and your moves).

## Comments on the code
someVariable  
someFunction  
SomeType  
SOME_MACRO  
SOME_CONSTANT  
SOME_COMPILE_TIME_FUNCTION  

Even funcs/procs that I consider private are marked \* so that I can include them in the docs.

templates FOR_sq_IN and FOR_sq_IN are used to iterate over the set squares in a BB

Code should be commented with documentation comments. Automatically generated docs is available for core functions/modules.

Code lenght is around 1500 lines (with some repetitive parts :( ), movegen being the most intensive part.

### Types / constants:
```
* BB        - possible values: {0,1}^64 = int64
* Square    - possible values: NO_SQUARE = -1, A1 = 0, B1 = 1, ..., G8 = 62, H8 = 63
* Color     - possible values: WHITE = 0, BLACK = 1
* Piece     - possible values: NO_PIECE = -1, PAWN = 1, KNIGHT = 2, BISHOP = 3, ROOK = 4, QUEEN = 5, KING = 6, KING_ROOK = 7, UNDO_MOVE = 8, NULL_MOVE = 9
* Board = object
        colors*: array[2, BB]                   # BBs for white and black pieces
        pieces*: array[6, BB]                   # BBs for pawns, knights, bishops, rooks, queens, kings
        activeColor*: Color                     # active color
        canCastle*: array[2, array[2, bool]]    # castling rights for white, black; queen side, king side
        isCheck*: bool                          # is current player in check?
        enPassant*: Square                      # target Square for en_passant (0 denotes none or idk maybe extend to range to -1)
        ply*: int                               # ply number
    - size of this object = 8 * 8B + 6B = 70B
    - 2 GB RAM can store 30 mil. positions
* Move = object                            
        piece*: Piece                           # Moving piece or KING_ROOK when castling
        frm*: Square                            # Origin square
        to*: Square                             # Destination square
        capturedPiece*: Piece                   # Piece type being captured or NO_PIECE
        promotion*: Piece                       # Piece promoting to or NO_PIECE
```

## Current state of the project
As of now the engine playes some reasonable moves, especially in the middlegame. It knows no endgame theory, except for being able to win (perhaps not in an ideal sequence) KRK ending.
When winning, it avoids draw by repetition or stalemate, when losing it tries to draw by these means. When allowed 10 second thinking it searches the game tree 4-8 plies deep, with quiescence search extending to 25 or deeper.
There's a simple algorithm for calculating time to be spent on a move based on the position and remaining time.
Next obvious step is to introduce transposition tables. 

## TODOs
there's around 50 TODOs in code
* better move ordering
    - PV collection
    - reorder all moves
* faster data manipulation (ref types etc.)
* judge draw detection - move50 and repetition
* do not calculate unnecesarry things for positions, that are only (not mate)-checking
* break search even mid search if it exceeds allocated time dramatically
* better time handling
* when all but 1 move suck, dont go deeper
* consider dropping isCheck from Board
* consider saving castling rights as bit flags - and make it compatible with 960
* hashing
* separate functions for generating moves (winning captures, trades, losing captures, noncaptures, etc.) instead of sorting the moves
* reduce repetitiveness and clutter
* pawn chain = good, and other pawn structure
* special evaluation of king
    - might be slightly more efficient given there is exactly 1 king of each color
    - uncastled king = bad
    - castled king with a pawn missing = bad
        - precalculated tables for bonuses/penalties for pawn structure around king?
* consider avoiding recursion
* create documentation comments for fields
* pondering - while opponnent's thinking - select (by low depth search) 1 or 2 best moves for him and then start a full depth search from there. If opponent ends up playing one of these moves, we'll have the response precomputed.
* mate finding algorithm in the endgame (dont evaluate positions, just try to force a mate)
* consider calculating branching factor using number of searched nodes instead of time taken

## Why Nim
Nim might just very well be my new favourite language.

*Nim is a statically typed compiled systems programming language. It combines successful concepts from mature languages like Python, Ada and Modula.*

*The goal for Nim is to be as fast as C, as expressive as Python, and as extensible as Lisp.*

### Specific features I like
* Distinct keywords for procedures, functions , methods and iterators.
* Distinct keywords let, const, var.
* Compilation time procedures.
* One thing that I miss in Python is a prettier lambda syntax. In Nim to square each number in a sequence `s` we can use `s.mapIt(it^2)` or `s.map(x => x^2)` (which is an experimental macro).
* I like how in R slices and ranges are the same thing. In Nim, `0..5` represent the (abstract) sequence of numbers 0 trough 5 (contrary to Python, 5 is included) and we can use it to slice sequences, or in a `for` loop. This yields a very readable code:
```
var b = a[0..5]
for i in 0..5:
    echo i
```
* Descriptive names. For example `long` in C# is 64 bits, while in C it is only 32 bits. In Nim, you have int32 and int64.
* UFCS. To determine a length of a sequence you can use `len(sequence)` or `sequence.len`. The second syntax is just a sytactic sugar and works in general with any function. If `d`,`e`, `f`,`g`,`h` are all functions int -> int then  
`h(g(f(e(d(x)))))` is equivalent to `x.d.e.f.g` and  
`map(sequence, function)` is equivalent to `sequence.map(function)`  
Difference between free functions and object methods vanishes and this feature replaces extension methods or pipes in other languages.
* Macros/templates. In Python you are stuck with the syntax Python provides. In Nim if you want some special syntax, you can just implement it.  
For example in OOP in Nim follows Pascal syntax, where we define a type separately and then we separately define methods which take the object they are to be operating on as a first argument, that is
```
type Animal = ref object of RootObj
  name: string
  age: int
method vocalize(self: Animal): string {.base.} = "..."
method ageHumanYrs(self: Animal): int {.base.} = self.age

type Dog = ref object of Animal
method vocalize(self: Dog): string = "woof"
method ageHumanYrs(self: Dog): int = self.age * 7

type Cat = ref object of Animal
method vocalize(self: Cat): string = "meow"
```
By writing a `class` macro, we can use more of a C# way where we define a class block - type definition and methods, which don't need a first argument to be the "this" object:
```
class Animal of RootObj:
  var name: string
  var age: int
  method vocalize(): string = "..."
  method age_human_yrs(): int = self.age  # `self` is injected

class Dog of Animal:
  method vocalize(): string = "woof"
  method age_human_yrs(): int = self.age * 7

class Cat of Animal:
  method vocalize(): string = "meow"
```
Or we can define a `modular` block in which all arithmetic operations are understood as modular:
```
modular(5741):
    var a = 2 ^ 1000 # = 4768
    var b = 1 / 3    # = 1914
    var c = 2 - 3    # = 5740
```
* Garbage collection, complex data types, complex procedure signatures (higher order etc.) and other forms of abstraction, while maintaining the speed of C code and in case it is needed acces to low level features like bit twiddling or pointers/manual memory allocation.


### Things I miss / don't like
* Built in BigInts. Nim supports a wide range of single word types, int8 tru int64 as well as their unsigned variants. This is very smart and beneficial in most cases. For some applications, Python's ability to handle arbitrarily large integers is handy. Of course, several BigInts libraries exist for Nim. Working with them might be a bit awkward though.
I would love to see Nim emulate int64 with two int32s in case 64 bit integers aren't available in the system. In similar way, I would love to see built in types int128, int256, int512 emulated by (fixed array) of 2, 4 or 8 int64s and intbig type implemented as an aribitrarily large sequence of int64s and arbitrary long integer literals.
* Easy and working parallel for, parallel map etc.
* GUI framework and Specialised IDE with graphical GUI designer.
* I dont' like that by default, all imported identifiers are available without qualification.
* Enums aren't allowed to index arrays or to perform arithmetics. In my engine this forces me to declare Color, Piece, Square as a range instead and explicitely introduce the values as individual constants.
