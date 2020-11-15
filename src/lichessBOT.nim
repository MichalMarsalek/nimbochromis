## This program connects to lichess API. It accepts challenges and plays games.

import httpclient, json, streams, net, strformat, asyncdispatch, strutils
import engine, board, movegen, time_management, evaluation

let TOKEN = readFile("token")
const HOST = "lichess.org"

iterator getStream*(path: string): JsonNode =
    ## Connect to a path, interprets the response as ndjson,
    ## that is, yields JsonNodes corresponding to the lines in the response.
    let s = newSocket()
    wrapSocket(newContext(), s)
    s.connect(HOST, Port(443))
    var req = &"GET {path} HTTP/1.1\r\nHost:{HOST}\r\nAuthorization: Bearer {TOKEN}\r\n\r\n"
    s.send(req)
    while true:
        var line = ""
        while line == "" or line[0] != '{':            
            line = s.recvLine
        yield line.parseJson

func getPlayer*(player: JsonNode): string =
    ## Reads a player name if present.
    ## Otherwise returns the whole node. The name is not present for stockfish AIs.
    if "name" in player:
        return player["name"].getStr
    return $player
    
proc post*(path, multipart=nil) =
    ## Posts `multipart` to `path`.
    let client = newHttpClient()
    client.headers["Authorization"] = &"Bearer {TOKEN}"
    discard client.post(&"https://{HOST}{path}", multipart=multipart)

proc sendMove*(id: string, move:Move) =
    ## Sends a move to be played.
    post(&"/api/bot/game/{id}/move/{$move}")
    
proc writeInChat*(id: string, text: string) =
    ## Writes a message to game chat.
    var data = newMultipartData()
    data["room"] = "player"
    data["text"] = text
    post(&"/api/bot/game/{id}/chat", multipart=data)

proc acceptChallenge*(id: string) =
    ## Accepts a challenge `id`.
    post(&"/api/challenge/{id}/accept")

proc playGame*(id: string) =
    ## Starts playing a game `id`.
    
    var gameInfo: JsonNode
    var gameInfoLoaded = false
    var AI: Game
    var lastMoves = ""
    for line in getStream("/api/bot/game/stream/" & id):
        var state: JsonNode
        if line["type"].getStr != "chatLine":
            if not gameInfoLoaded:
                gameInfo = line
                gameInfoLoaded = true
                state = gameInfo["state"]
                var players = [getPlayer(gameInfo["white"]), getPlayer(gameInfo["black"])]
                let myColor = if players[BLACK] == "nimbochromis": BLACK else: WHITE
                AI = newGame(state["moves"].getStr, myColor, gameInfo["clock"]["increment"].getFloat / 1000.0)
                echo("Game: " & gameInfo["id"].getStr & " White: " & getPlayer(gameInfo["white"]) & " Black: " & getPlayer(gameInfo["black"]))
                writeInChat(id, &"Hello {players[1-myColor]}. Good luck, have fun!")
            else:
                state = line
                let currMoves = state["moves"].getStr
                if currMoves != lastMoves:
                    let moveStr = currMoves.split(" ")[^1]
                    echo("Move: ", moveStr)
                    lastMoves = currMoves
                    AI.advance(moveStr)
            if state["status"].getStr != "started":
                echo state["status"].getStr
                writeInChat(id, &"Thank you for the game!")
                return
            AI.updateTime(state["wtime"].getFloat/1000.0, state["btime"].getFloat/1000.0)
            if AI.isNimbochromisTurn:
                let move = AI.getMove
                echo("Nimbochromis plays ", move)
                sendMove(id, move)

proc getCurrentGame*(): string =
    ## Returns an ID of current game if or "" if no playing any game.
    let client = newHttpClient()
    client.headers["Authorization"] = &"Bearer {TOKEN}"
    let req = &"https://{HOST}/api/account/playing"
    var games = client.getContent(req).parseJson["nowPlaying"]
    if games.len == 0:
        return ""
    return games[0]["gameId"].getStr    

proc getFirstRelevantChallenge*(): string =
    ## Returns an ID of the first challenge that should be accepted.
    ## Blocks until such challenge is presented.
    for event in getStream("/api/stream/event"):
        if event["type"].getStr == "challenge":
            let challenge = event["challenge"]
            if challenge["variant"]["key"].getStr == "standard" and challenge["timeControl"]["type"].getStr == "clock":
                return challenge["id"].getStr    

proc waitAround*() =
    ## Main loop. Starts playing any ongoing game. Accepts challenges.
    while true:
        let game = getCurrentGame()
        if game != "":
            playGame(game)
        var challenge = getFirstRelevantChallenge()
        if challenge != "":
            acceptChallenge(challenge)
    
        
when isMainModule:
    waitAround()