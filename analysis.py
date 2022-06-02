from state import *
import json
import random
from string_utils import Dashboard, Blank, move_to_str, moves_to_str, str_to_move, str_to_moves, print_resources
from move import move_target
from itertools import permutations

def legal_swaps(moves):
    """
    generate all single perturbations of a move-ordering
    """
    swaps = []
    for i in range(len(moves)):
        for j in range(i + 1, len(moves)):
            if moves[i]["target"] == move_target.WAIT or moves[j]["target"] == move_target.WAIT:
                break
            if moves[i]["target"] == moves[j]["target"] and moves[i]["index"] == moves[j]["index"]:
                break #cannot swap beyond this point
            if (
                moves[i]["target"] == move_target.CHAMPION and 
                moves[j]["target"] == move_target.CHAMPION and
                moves[i]["level"] == 0 and
                moves[i]["index"] < moves[j]["index"]
            ):
                break #can't get later champions before earlier ones
            swaps.append((i,j))
            
    for i in range(len(moves)):
        for j in range(i)[::-1]:
            if moves[i]["target"] == move_target.WAIT or moves[j]["target"] == move_target.WAIT:
                break
            if moves[i]["target"] == moves[j]["target"] and moves[i]["index"] == moves[j]["index"]:
                break #cannot swap beyond this point
            if (
                moves[i]["target"] == move_target.CHAMPION and 
                moves[j]["target"] == move_target.CHAMPION and
                moves[j]["level"] == 0 and
                moves[j]["index"] < moves[i]["index"]
            ):
                break #can't get later champions before earlier ones
            swaps.append((i,j))
    return swaps

def swap_descent(state, moves, levels = 1, dashboard = Dashboard()):
    """
    Tries all single permutations per level and chooses the greediest one
    """
    score = state.score_moves(moves)
    if levels == 0:
        return score, moves
    moves = [move for move in moves] #in-place copy
    while True:
        #try every swap and see if it bumps us out of this local maximum
        swap_score, swap_moves = swap_descent(state, moves, levels - 1, dashboard = Blank()) #try current order first
        if swap_score > score:
            score = swap_score
            moves = swap_moves
            break
        count = 0
        swaps = legal_swaps(moves)
        n_legal_swaps = len(swaps)
        for i, j in swaps:            
            count += 1
            dashboard.set_score(score)
            dashboard.set_moves(moves)
            dashboard.show()
            moves.insert(j, moves.pop(i))
            swap_score, swap_moves = swap_descent(state, moves, levels - 1, dashboard = Blank())
            if swap_score > score:
                score = swap_score
                moves = swap_moves
                break
            else:
                moves.insert(i, moves.pop(j))
        else:
            break
    return score, moves
                      
def simulate(state, runs, temperature = 3, dashboard = Dashboard()):
    score = 0
    moves = []
    dashboard.set_step("simulating")
    dashboard.set_score(0)
    for i in range(runs):
        dashboard.set_progress((i+1)/runs)
        dashboard.show()
        sim_state = State()
        sim_state.copy(state)
        sim_state.time = state.time * temperature
        while sim_state.time > 0:
            legal_moves = sim_state.legal_moves()
            move = legal_moves[random.randint(0, len(legal_moves) - 1)]
            sim_state.apply_move(move)
        if sim_state.resources["damage"] > score:
            score = sim_state.resources["damage"]
            moves = sim_state.log[:sim_state.ilog]
            dashboard.set_score(state.score_moves(moves))
            dashboard.set_moves(moves)
    return moves
                      
def anneal_swap(state, moves, start_temperature = 1, number_of_runs = 2, dashboard = Dashboard()):
    anneal_state = State()
    anneal_state.copy(state)
    for i in range(number_of_runs):
        temperature = start_temperature - (start_temperature - 1) * i/(number_of_runs-1)
        dashboard.set_step(f"Annealing : temperature = {temperature}")
        dashboard.set_progress((i+1)/number_of_runs)
        dashboard.set_score(state.score_moves(moves))
        dashboard.set_moves(moves)
        dashboard.show()
        anneal_state.time = state.time * temperature
        _, moves = swap_descent(anneal_state, moves, 1, dashboard)
    return moves
        
def perturbation(
    state,
    moves, 
    runs, 
    reset_on_improvement = True, 
    number_of_swaps = 3, 
    dashboard = Dashboard()
):
    score, moves = swap_descent(state, moves, 1, Blank())
    count = 0
    dashboard.set_step(f"{number_of_swaps + 1}-swap perturbation")
    while count < runs:
        moves_copy = [move for move in moves]
        for _ in range(number_of_swaps):
            i,j = random.choice(legal_swaps(moves_copy))
            moves_copy.insert(j, moves_copy.pop(i))
        new_score, new_moves = swap_descent(state, moves_copy, 1, Blank())
        if new_score > score:
            score = new_score
            moves = new_moves
            if reset_on_improvement:
                count = 0
            else:
                count += 1
        else:
            count += 1
        dashboard.set_progress(count/runs)
        dashboard.set_score(score)
        dashboard.set_moves(moves)
        dashboard.show()
    return score, moves


def verify_legal_moves(moves):
    """
    A few rules must be observed for move order
    1) ci0 must come before cjk if i < j (champions unlock in order, this will need to be adjusted for the 6th event)
    2) xij must come before xik if j < k (all upgrades level up one level at a time)
    3) w00 is at the end
    """
    legal = True
    for i in range(len(moves) - 1):
        if not legal:
            break
        move1 = moves[i]
        #condition 3
        if move1["target"] == WAIT:
            legal = False
            break
        for j in range(i, len(moves)):
            if not legal:
                break
            move2 = moves[j]
            #condition 1
            if (
                move1["target"] == move2["target"] == move_target.CHAMPION and 
                move2["level"] == 0 and 
                move2["index"] < move1["index"]
            ):
                legal = False
                break
            #condition 2
            if (
                move1["target"] == move2["target"] and 
                move1["index"] == move2["index"] and 
                move2["level"] < move1["level"]
            ):
                legal = False
                break
    return legal
            
def window_swap(state, moves, window_size, dashboard = Dashboard()):
    """
    tries all permutations of a fixed-length window accross entire move plan
    """
    best = state.score_moves(moves)
    windows = len(moves) -window_size
    count = 0
    dashboard.set_step("local optimization")
    for window_start in range(len(moves) -window_size):
        count += 1
        dashboard.set_progress(count / (len(moves) -window_size))
        dashboard.set_score(best)
        dashboard.set_moves(moves)
        dashboard.show()
        window_end = window_start + window_size
        for move_permutation in permutations(moves[window_start:window_end]):
            if not verify_legal_moves(move_permutation):
                continue
            test_moves = moves[:window_start] + list(move_permutation) + moves[window_end:]
#             score = swap_descent(state, test_moves, False)
            score = state.score_moves(test_moves)
            if score > best:
                best = score
                moves = test_moves
                return best, moves
    return best, moves

def set_event_by_name(event_name):
    with open("event_info/" + event_name + ".json", "r") as infile:
        set_event_info(json.load(infile))
        
def find_solution(event_name, gem_level):
    set_event_by_name(event_name)
    state = State()
    state.gem_level = gem_level
    return plan(state, event_name)
        
def plan(
    state,
    event_name = None,
    simulate_runs = 10000, 
    temperature = 3, 
    anneal_steps = 41,
    perturbation_min_swaps = 2,
    perturbation_max_swaps = 6,
    perturbation_runs = 100,
    swap_levels = 2,
    swap_window = 9,
    dfs_max_time = 10,
    repeat_if_improved = True
):
    """
    Runs a gauntlet of methods to find a good sequence of moves
    """
    if event_name is None:
        event_name = "custom"
    dashboard = Dashboard()
    dashboard.set_event(event_name)
    dashboard.set_goal(get_event_info()["goal"])
    dashboard.set_state(state)
    moves = simulate(state, simulate_runs, temperature = temperature, dashboard = dashboard)
    dashboard.set_step("simulation complete")
    dashboard.set_progress("")
    dashboard.set_score(state.score_moves(moves))
    dashboard.set_moves(moves)
    dashboard.show()
    moves = anneal_swap(state, moves, 3, anneal_steps, dashboard = dashboard)
    score = state.score_moves(moves)
    dashboard.set_step("annealing complete")
    dashboard.set_progress("")
    dashboard.set_score(score)
    dashboard.set_moves(moves)
    dashboard.show()
    
    while True:
        new_score = 0
        new_moves = moves.copy()
        moves = moves.copy()
        for number_of_swaps in range(perturbation_min_swaps, perturbation_max_swaps + 1):
            new_score, new_moves = perturbation(
                state,
                moves, 
                perturbation_runs, 
                reset_on_improvement = False, 
                number_of_swaps = number_of_swaps,
                dashboard = dashboard
            )
            if new_score > score and repeat_if_improved:
                break
        if new_score > score:
            score = new_score
            moves = new_moves.copy()
            if repeat_if_improved:
                continue
        dashboard.set_step("global optimization")
        new_score, new_moves = swap_descent(state, moves, levels = swap_levels, dashboard = dashboard)
        if new_score > score:
            score = new_score
            moves = new_moves.copy()
            if repeat_if_improved:
                continue
        new_score, new_moves = window_swap(state, moves, swap_window, dashboard = dashboard)
        if new_score > score:
            score = new_score
            moves = new_moves.copy()
            if repeat_if_improved:
                continue
            
        dashboard.set_step("finished")
        dashboard.set_progress("")
        dashboard.set_score(score)
        dashboard.set_moves(moves)
        dashboard.show(force = True)
        break

    return score, moves

def save_solution(score, moves, gem_level, event_name):
    with open("solutions.csv", "a+") as outfile:
        outfile.write(f"{event_name},{gem_level},{moves_to_str(moves)},{int(score)}\n")