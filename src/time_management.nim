func predict_reamining_moves(material: int): int =
    ## Predicts the amount of remaining moves based on the phase of the game
    
    if material < 10:
        return 10
    if material < 20:
        return 18
    if material < 30:
        return 24
    return material

func allocate_time*(material: int, myTime, opponentTime, increment: float): float =
    ## Calculates ideal amount of seconds that should be spent on a move.
    
    let moves = predict_reamining_moves(material).float
    var remTime = myTime + moves * increment
    if increment >= 1.0 and myTime - 3.0 * increment > 0:
        remTime -= 3.0 * increment
    elif increment >= 1.0:
        return increment / 2.0
    result = remTime / moves
    if 30 < material and material < 50:
        result *= 1.5
    elif material >= 50:
        result /= 1.4
    result = min(result, myTime/3.0)
    if opponentTime < myTime and myTime - opponentTime > result:
        result *= 2.0
    