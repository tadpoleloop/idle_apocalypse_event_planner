#cython: cdivision=True
from move cimport Move, move_target
from event_info cimport MAX_CHAMPIONS
from state import get_event_info, set_event_info
from state cimport State, event_info
from time import sleep, time
import json
import random
from string_utils import Dashboard, Blank, print_plan, moves_to_str, pretty_print_time

# cdef struct Toggle:
#     int time, index, direction
    
ctypedef Move Upgrade
    
cdef struct UpgradeToggle:
    Upgrade upgrade
    bint toggles[MAX_CHAMPIONS]
    
cdef enum Score_mode:
    DAMAGE_MODE, TIME_MODE, HYBRID_MODE
    
def verify_legal_moves(moves):
    """
    A few rules must be observed for move order
    1) ci0 must come before cjk if i < j (champions unlock in order)
    2) xij must come before xik if j < k (all upgrades level up one level at a time)
    3) ci0 must come before ti0 (champions must be unlocked before you can toggle)
    4) w00 is at the end
    
    returns 0 for legal, and 1, 2, 3, 4 for which rule it breaks
    """
    
    if moves[-1]["target"] != move_target.WAIT:
        #condition 4
        return 4
    legal = True
    for i in range(len(moves) - 1):
        if not legal:
            break
        move1 = moves[i]
        #condition 4
        if move1["target"] == move_target.WAIT:
            legal = False
            break
        for j in range(i, len(moves)):
            move2 = moves[j]
            #condition 1
            if (
                move1["target"] == move2["target"] == move_target.CHAMPION and 
                move2["meta"] == 0 and 
                move2["index"] < move1["index"]
            ):
                legal = False
                break
            #condition 2
            if (
                move1["target"] != move_target.TOGGLE and 
                move1["target"] == move2["target"] and 
                move1["index"] == move2["index"] and 
                move2["meta"] < move1["meta"]
            ):
                legal = False
                break
    return legal
    

def simulate(
    state, 
    runs, 
    temperature = 1, 
    dashboard = Dashboard(), 
    epsilon = 1, 
    allow_toggles = False, 
    epsilon_sweep = True
):
    score = -1
    best_moves = []
    dashboard.set_step("simulating")
    for i in range(runs):
        if epsilon_sweep:
            epsilon = 1. - i / runs
        dashboard.set_progress((i+1.)/runs)
        dashboard.show()
        sim_state = State()
        sim_state.copy(state)
        sim_state.time = state.time * temperature
        moves = []
        while sim_state.time > 0:
            legal_moves = [
                move for move in sim_state.legal_moves() if allow_toggles or move['target'] != move_target.TOGGLE
            ]
            if random.random() < epsilon:
                move = legal_moves[random.randint(0, len(legal_moves) - 1)]
            else:
                move = legal_moves[0]
            sim_state.apply_move(move)
            moves.append(move)
        if sim_state.resources.damage > score:
            score = sim_state.resources.damage
            best_moves = moves
            dashboard.set_moves(moves)
    sim_state = State()
    sim_state.copy(state)
    for move in best_moves:
        sim_state.apply_move(move)
            
    #fill out the rest of the unpurchased upgrades
    for i in range(get_event_info()['n_champions']):
        champion = get_event_info()['champions'][i]
        for j in range(sim_state.champion_levels[i], champion["max_level"] - 1):
            best_moves.insert(-1, {'target': move_target.CHAMPION, 'index': i, 'meta': j})
    for i in range(get_event_info()['n_resources']):
        resource = get_event_info()['resources'][i]
        for j in range(sim_state.resource_levels[i], resource["max_level"] - 1):
            best_moves.insert(-1, {'target': move_target.RESOURCE, 'index': i, 'meta': j})
    for j in range(sim_state.speed_level, get_event_info()['speed']['max_level'] - 1):
        best_moves.insert(-1, {'target': move_target.SPEED, 'index': 0, 'meta': j})
    if get_event_info()['has_speed2']:
        for j in range(sim_state.speed2_level, get_event_info()['speed2']['max_level'] - 1):
            best_moves.insert(-1, {'target': move_target.SPEED2, 'index': 0, 'meta': j})
    for j in range(sim_state.damage_level, get_event_info()['damage']['max_level'] - 1):
        best_moves.insert(-1, {'target': move_target.DAMAGE, 'index': 0, 'meta': j})
    dashboard.show(force = True)
    return best_moves

cdef class Strategy:
    """
    A strategy will consist of an order of upgrades and a schedule of toggles
    """
    cdef public:
        State state
        UpgradeToggle upgrades[120]
        int n_upgrades
        Score_mode score_mode
        int stop
        
    def __init__(self, state = None):
            
        cdef int i
        
        if state is None:
            self.state = State()
        else:
            self.state = State().copy(state)
        self.n_upgrades = 0
        score_mode = DAMAGE_MODE
        
    cpdef Strategy copy(self, Strategy strategy):
        self.state.copy(strategy.state)
        self.upgrades = strategy.upgrades #this should copy c arrays
        self.n_upgrades = strategy.n_upgrades
        self.score_mode = strategy.score_mode
        return self
    
    def set_event_by_name(self, event_name):
        self.state.set_event_by_name(event_name)
        
    def from_moves(self, list moves):
        """
        assumes that the toggle direction at the the of upgrade was the direction the entire time
        wont be able to injest partial duration toggles
        """
        cdef:
            Move move
            State state
            int i
            
        state = State().copy(self.state)
        self.n_upgrades = 0
            
        for move in moves:
            if move.target == move_target.WAIT:
                pass
            elif move.target == move_target.TOGGLE:
                pass
            else:
                self.upgrades[self.n_upgrades].upgrade = move
                for i in range(MAX_CHAMPIONS):
                    self.upgrades[self.n_upgrades].toggles[i] = state.toggles[i]
                self.n_upgrades += 1
            state.apply_move(move)
        self.upgrades[self.n_upgrades].upgrade = Move(move_target.WAIT, 0, 0)
        self.upgrades[self.n_upgrades].toggles = state.toggles
        self.n_upgrades += 1
        
    @staticmethod
    def collapse_toggles(list moves):
        """
        1) if several toggles appear consecutively keep only the last one for each champion
        2) if a toggle appears that is the same direction as it is already pointing, keep the first one
        3) assumes that we start pointing left <-
        """
        
        cdef:
            set moves_to_remove
            object current_toggles
            int i
        moves_to_remove = set()
        current_toggles = set()
        for i in range(len(moves))[::-1]:
            if moves[i]['target'] == move_target.TOGGLE:
                if moves[i]['index'] in current_toggles:
                    moves_to_remove.add(i)
                else:
                    current_toggles.add(moves[i]['index'])
            else:
                current_toggles.clear()
        moves = [moves[i] for i in range(len(moves)) if i not in moves_to_remove]
        moves_to_remove.clear()
        current_toggles = {i: 0 for i in range(get_event_info()['n_champions'])}
        for i in range(len(moves)):
            if moves[i]['target'] == move_target.TOGGLE:
                if moves[i]['meta'] == current_toggles[moves[i]['index']]:
                    moves_to_remove.add(i)
                else:
                    current_toggles[moves[i]['index']] = moves[i]['meta']
        moves = [moves[i] for i in range(len(moves)) if i not in moves_to_remove]
        return moves
        
    cpdef list get_moves(self):
        cdef:
            int n_moves
            Move moves[1000]
        n_moves, _, _, _ = self._get_moves_damage_time(moves)
        return [moves[i] for i in range(n_moves)]
    
    cpdef double score(self, double toggle_penalty = 0):
        """
        toggle penalty: 
            For score: is the proportion of the goal per toggle
            For time:  is the proportion of time remaining per toggle
        This is to add an incentive for fewer toggles
        """
        cdef:
            int n_moves, n_toggles#, TIME_CONSTANT
            Move moves[1000]
            double damage, time_remaining
        
        n_moves, n_toggles, damage, time_remaining = self._get_moves_damage_time(moves)
        if self.score_mode == DAMAGE_MODE:
            return damage - n_toggles * toggle_penalty * event_info.goal
        elif self.score_mode == TIME_MODE:#can go negative
            return time_remaining - n_toggles * toggle_penalty * self.state.time
        elif self.score_mode == HYBRID_MODE:
            #proportion of damage + proportion of time remaining
            return (
                damage / event_info.goal + 
                time_remaining / self.state.time - 
                n_toggles * toggle_penalty 
            )
        else:
            raise #how?
            
    def get_moves_damage_time(self):
        """
        python wrapper for _get_moves_damage_time
        """
        cdef:
            Move moves[1000]
            int i, n_moves
            double damage, time_remaining
        n_moves, _, damage, time_remaining = self._get_moves_damage_time(moves)
        return {
            "moves": [moves[i] for i in range(n_moves)],
            "damage": damage,
            "time": time_remaining
        }

    #not sure if ctuples or pointers are better here, probably about the same
    cdef (int, int, double, double) _get_moves_damage_time(self, Move* moves):
        """
        This function does many things
        It is designed to step through the strategy once, and return information on:
        1. moves
        2. score
        3. time to complete
        so that the strategy only needs to be simulated once.
        
        The return is a ctuple packing of (n_moves, n_toggles, damage, time)
        """
        cdef:
            int i, j, n_toggles, n_moves, TIME_CONSTANT, start_time
            State state
            double damage, start_damage, time_remaining
            
        TIME_CONSTANT = 100 * 24 * 3600 #time added to state to not terminate simulation prematurely
        n_moves= 0
        n_toggles = 0
        state = State().copy(self.state)
        state.time += TIME_CONSTANT
        time_remaining = - TIME_CONSTANT
        damage = 0
        
        
        for i in range(self.n_upgrades):
            for j in range(event_info.n_champions):
                if event_info.champions[j].has_swap and state.toggles[j] != self.upgrades[i].toggles[j]:
                    moves[n_moves] = Move(move_target.TOGGLE, j, self.upgrades[i].toggles[j])
                    state.apply_move(moves[n_moves])
                    n_moves += 1
                    n_toggles += 1
            start_time = state.time
            start_damage = state.resources.damage
            moves[n_moves] = self.upgrades[i].upgrade
            state.apply_move(moves[n_moves])
            n_moves += 1
            if start_time > TIME_CONSTANT and state.time <= TIME_CONSTANT: #time expired
                #interpolate damage
                damage = start_damage + (
                    (TIME_CONSTANT - start_time) * 
                    (state.resources.damage - start_damage) / 
                    (state.time - start_time)
                )
                    
            if start_damage < event_info.goal and state.resources.damage >= event_info.goal: #goal reached
                #interpolate time
                time_remaining = start_time - TIME_CONSTANT + (
                    (event_info.goal - start_damage) *
                    (state.time - start_time) / 
                    (state.resources.damage - start_damage)
                )
        return (n_moves, n_toggles, damage, time_remaining)
        
            
    def legal_swaps(self):
        """
        return a list of possible moves that can be moved to another location (from, to)
        this function assumes that there is only one WAIT and it is at the end.
        """
        cdef:
            int i, j
            list swaps
            Upgrade ui, uj
            
        swaps = []
        for i in range(self.n_upgrades): 
            ui = self.upgrades[i].upgrade
            #moving ahead
            for j in range(i + 1, self.n_upgrades):
                uj = self.upgrades[j].upgrade
                if ui.target == move_target.WAIT or uj.target == move_target.WAIT:
                    break
                if ui.target == uj.target and ui.index == uj.index:
                    break #cannot swap beyond this point
                if (
                    ui.target == move_target.CHAMPION and 
                    uj.target == move_target.CHAMPION and
                    ui.meta == 0 and
                    ui.index < uj.index
                ):
                    break #can't get later champions before earlier ones
                swaps.append((i,j))
                
            #moving back
            for j in range(i-1, -1, -1):
                uj = self.upgrades[j].upgrade
                if ui.target == move_target.WAIT or uj.target == move_target.WAIT:
                    break
                if ui.target == uj.target and ui.index == uj.index:
                    break #cannot swap beyond this point
                if (
                    ui.target == move_target.CHAMPION and 
                    uj.target == move_target.CHAMPION and
                    uj.meta == 0 and
                    uj.index < ui.index
                ):
                    break #can't get later champions before earlier ones
                swaps.append((i,j))
        return swaps
        
    
    cdef void apply_swap(self, int i, int j):
        cdef:
            int k
            UpgradeToggle ut
        ut = self.upgrades[i]
        k = i
        while k != j: #hacky-looking way of looping from i to j
            self.upgrades[k] = self.upgrades[k + (j > i) - (i > j)]
            k += (j > i) - (i > j)
        self.upgrades[j] = ut
        
    cdef inline void apply_toggle(self, int upgrade_i, int champion_i):
        self.upgrades[upgrade_i].toggles[champion_i] ^= 1
            
    cpdef double swap_toggle_descent(
        self, 
        int depth = 1, 
        object dashboard = Dashboard(), 
        bint root_level = 0,
        double toggle_penalty = 0,
        bint scan_swaps = 1,
        bint scan_toggles = 1
    ) except -1:
        """
        tests every legal shift of an upgrade in the upgrade order
        and every legal toggle to see if there is an improvement in score
        """
        cdef:
            double score, new_score
            Strategy strategy, best_strategy
            bint improved
            list swaps
            int i, j, k, count, step, total, n_toggles, upgrade_i, champion_i
            UpgradeToggle ut
        n_toggles = 0
        for champion_i in range(event_info.n_champions):
            n_toggles += event_info.champions[champion_i].has_swap
        score = self.score(toggle_penalty = toggle_penalty)
        if self.stop:
            return score
        if depth == 0:
            return score
        improved = True
        #three levels of Strategy
        #self: final strategy, don't want to change it until complete
        #strategy: the test strategy
        #best_strategy: the best test so far. will update self <- best_strategy at the end.
        strategy = Strategy()
        best_strategy = Strategy().copy(self)
        while improved:
            dashboard.show()
            improved = False
            if depth > 1:
                #try current order first
                strategy.copy(self)
                new_score = strategy.swap_toggle_descent(
                    depth - 1, 
                    Blank(),
                    0,
                    toggle_penalty,
                    scan_swaps,
                    scan_toggles
                )
                if self.stop:
                    break
                if new_score == -1:
                    raise
                if new_score > score:
                    score = new_score
                    best_strategy.copy(strategy)
                    dashboard.set_moves(best_strategy.get_moves())
                    improved = True
                strategy.copy(self)
            if scan_swaps:
                swaps = self.legal_swaps()
            else:
                swaps = []
            count = 0
            total = len(swaps) + scan_toggles * self.n_upgrades * n_toggles
            for i, j in swaps:
                count += 1
                if root_level:
                    dashboard.set_progress((<double> count) / total)
                dashboard.show()
                strategy.copy(self)
                strategy.apply_swap(i, j)
                swap_score = strategy.swap_toggle_descent(
                    depth - 1, 
                    Blank(), 
                    0,
                    toggle_penalty,
                    scan_swaps,
                    scan_toggles
                )
                if self.stop:
                    break
                if swap_score == -1:
                    raise
                if swap_score > score:
                    score = swap_score
                    best_strategy.copy(strategy)
                    dashboard.set_moves(best_strategy.get_moves())
                    improved = True
            if scan_toggles:
                for upgrade_i in range(self.n_upgrades):
                    if self.stop:
                        break
                    for champion_i in range(event_info.n_champions):
                        if event_info.champions[champion_i].has_swap:
                            count += 1
                            if root_level:
                                dashboard.set_progress((<double> count) / total)
                            dashboard.show()
                            strategy.copy(self)
                            strategy.apply_toggle(upgrade_i, champion_i)
                            toggle_score = strategy.swap_toggle_descent(
                                depth - 1, 
                                Blank(),
                                0,
                                toggle_penalty,
                                scan_swaps,
                                scan_toggles
                            )
                            if self.stop:
                                break
                            if toggle_score == -1:
                                raise
                            if toggle_score > score:
                                score = toggle_score
                                best_strategy.copy(strategy)
                                dashboard.set_moves(best_strategy.get_moves())
                                improved = True
            if self.stop:
                break
            self.copy(best_strategy)
        return score
    
    cpdef double perturbation(
        self,
        int runs, 
        bint reset_on_improvement = 0, 
        int number_of_swaps = 3,
        double toggle_frequency = 0.5,
        object dashboard = Dashboard(),
        double toggle_penalty = 0
    ) except -1:
        """
        Sample random swaps and then run a 1-depth optimization.
        This is to attempt to dislodge the strategy from local optima.
        """
        cdef:
            double score, new_score
            list moves, moves_copy, 
            int i, j, k, count, n_toggle_champions, champion_i, upgrade_i
            Strategy strategy
            list p_toggle_champions
            int toggle_champions[MAX_CHAMPIONS]
        dashboard.set_moves(self.get_moves())
        score = self.swap_toggle_descent(1, Blank(), 0, toggle_penalty, 1, 1)
        if self.stop:
            return score
        if score == -1:
            raise
        count = 0
        dashboard.set_step(f"{number_of_swaps + 1}-swap perturbation")
        strategy = Strategy()
        n_toggle_champions = 0
        for champion_i in range(event_info.n_champions):
            if event_info.champions[champion_i].has_swap:
                toggle_champions[n_toggle_champions] = champion_i
                n_toggle_champions += 1
        if n_toggle_champions == 0:
            toggle_frequency = 0
        while count < runs:
            strategy.copy(self)
            for k in range(number_of_swaps):
                legal_swaps = strategy.legal_swaps()
                if len(legal_swaps) > 0 and random.random() > toggle_frequency:
                    i,j = random.choice(legal_swaps)
                    strategy.apply_swap(i,j)
                elif n_toggle_champions > 0:
                    upgrade_i = random.randint(0, self.n_upgrades - 1)
                    champion_i = toggle_champions[random.randint(0, n_toggle_champions - 1)]
                    strategy.apply_toggle(upgrade_i, champion_i)
                else:
                    return score #?
            new_score = strategy.swap_toggle_descent(1, Blank(), 0, toggle_penalty, 1, 1)
            if self.stop:
                return score
            if new_score == -1:
                raise
            if new_score > score:
                score = new_score
                self.copy(strategy)
                dashboard.set_moves(self.get_moves())
                if reset_on_improvement:
                    count = 0
                else:
                    count += 1
            else:
                count += 1
            dashboard.set_progress((<double> count) /runs)
            dashboard.show()
        return score
                            
    def plan(
        self,
        int simulate_runs = 10000, 
        str mode = "damage",
        int swap_levels = 2,
        int perturbation_min_swaps = 2,
        int perturbation_max_swaps = 5,
        int perturbation_runs = 100,
        bint repeat_if_improved = 1,
        bint simulation_allow_toggles = 0,
        double toggle_penalty = 0.0001,
        object dashboard = None,
        object event_name = None,
    ):
        """
        Runs a gauntlet of methods to find a good sequence of moves
        """
        cdef:
            double score, new_score, temperature, toggle_frequency
            int time_step, anneal_i
            bint has_toggles
            list moves
            State state
            
        if event_name is None:
            event_name = "custom"
        if dashboard is None:
            dashboard = Dashboard()
            dashboard.set_event(event_name)
            dashboard.set_state(State().copy(self.state))
        if mode == "damage":
            self.score_mode = DAMAGE_MODE
        elif mode == "time":
            self.score_mode = TIME_MODE
        elif mode == "hybrid":
            self.score_mode = HYBRID_MODE
        else:
            raise NotImplementedError
        has_toggles = any(event_info.champions[i].has_swap for i in range(event_info.n_champions))
        if has_toggles:
            toggle_frequency = 0.
        else:
            toggle_frequency = 0.5
            
        if self.n_upgrades == 0: #random simulation to seed the move list
            moves = self.collapse_toggles(
                simulate(
                    self.state, 
                    simulate_runs,
                    dashboard = dashboard, 
                    allow_toggles = simulation_allow_toggles
                )
            )
            assert(verify_legal_moves(moves))
            self.from_moves(moves)
            dashboard.set_step("simulation complete")
            dashboard.set_progress("")
            dashboard.set_moves(self.get_moves())
            dashboard.show(force = True)
        dashboard.set_step("Initial optimization")
        self.swap_toggle_descent(1, dashboard, toggle_penalty = toggle_penalty)
        dashboard.set_progress(1)
        dashboard.show(force = True)
        score = self.score()
        repeat = True
        while repeat:
            repeat = False
            new_score = score #reinitialization
            for number_of_swaps in range(perturbation_min_swaps, perturbation_max_swaps + 1):
                new_score = self.perturbation(
                    perturbation_runs, 
                    reset_on_improvement = False, #could add this as a parameter
                    toggle_frequency = toggle_frequency,
                    number_of_swaps = number_of_swaps,
                    dashboard = dashboard,
                    toggle_penalty = toggle_penalty
                )
                if self.stop:
                    break
                if new_score == -1: #exception raised
                    break
                new_score = self.score()
                if new_score > score and repeat_if_improved:
                    break #need to break this loop first to repeat the outer loop
            if self.stop:
                break
            if new_score == -1:
                raise
            if new_score > score:
                score = new_score
                if repeat_if_improved:
                    repeat = True
                    continue
            dashboard.set_step("global optimization")
            new_score = self.swap_toggle_descent(
                depth = swap_levels, 
                dashboard = dashboard, 
                root_level = True,
                toggle_penalty = toggle_penalty
            )
            if self.stop:
                break
            if new_score == -1:
                raise
            if new_score > score:
                score = new_score
                if repeat_if_improved:
                    repeat = True
                    continue
        if self.stop:
            dashboard.set_step("interrupted")
        else:
            dashboard.set_step("finished")
        dashboard.set_progress("")
        dashboard.set_moves(self.get_moves())
        dashboard.show(force = True)
        return score
    
    def prefer_champion(self, event_name, champion_indices, **kwargs):
        for damage in [0.1, 0.25, 0.5, 1]:
            with open(f'event_info/{event_name}.json', 'r') as infile:
                d = json.load(infile)
            for i in range(d['n_champions']):
                if i in champion_indices:
                    continue
                for j in range(d['champions'][i]['max_level']):
                    d['champions'][i]['revenue_toggle'][j][4] =  d['champions'][i]['revenue_toggle'][j][4] * damage
                    d['champions'][i]['revenue'][j][4] =  d['champions'][i]['revenue'][j][4] * damage
            set_event_info(d)
            plan_name = (
                f"{event_name} preferring {[d['champions'][i]['name'] for i in champion_indices]} @{damage} damage"
            )
            score = self.plan(event_name = plan_name, **kwargs)
        return score
    
    def crawl(self, move_step_size = 5, **kwargs):
        cdef:
            Strategy strategy
        strategy = Strategy()
        strategy.copy(self)
        scores = {}
        moves = []
        dashboard = kwargs.pop("dashboard", Dashboard())
        original_event_name = dashboard.event
        while strategy.state.time > 0:
            dashboard.set_event(original_event_name)
            dashboard.set_state(strategy.state)
            strategy.plan(dashboard = dashboard, **kwargs)
            scores[strategy.state.time] = strategy.score()
            strategy_moves = strategy.get_moves()
            for move in strategy_moves[:move_step_size]:
                moves.append(move)
                strategy.state.apply_move(move)
            strategy.from_moves(strategy_moves[move_step_size:])
            if strategy.n_upgrades == 0:
                break
        self.from_moves(moves)
        return scores
    
    def anneal(self, temperature = 2, *args, **kwargs):
        cdef:
            Strategy strategy
            State state
            
        strategy = Strategy()
        strategy.copy(self)
        state = State()
        state.copy(self.state)
        dashboard = kwargs.pop("dashboard", Dashboard())
        event_name = dashboard.event
        dashboard.set_event(event_name + f" @Temperature = {temperature}")
        state.time *= temperature
        swap_levels = kwargs.pop("swap_levels", 2)
        strategy.plan(dashboard = dashboard, swap_levels = 1, *args, **kwargs)
        dashboard.set_event(event_name)
        self.from_moves(strategy.get_moves())
        return self.plan(dashboard = dashboard, swap_levels = swap_levels, *args, **kwargs)
        
        
        
        
    def show(self, include_urgency = False):
        return print_plan(self.state, self.get_moves(), include_urgency = include_urgency)
    
    def save(self, event_name):
        cdef Move moves[1000]
        gem_level = self.state.gem_level
        moves_s = moves_to_str(self.get_moves())
        n_moves, _, damage, time_remaining = self._get_moves_damage_time(moves)
        with open("solutions.csv", "a+") as outfile:
            outfile.write(f"{event_name},{gem_level},{moves_s},{int(damage)},{int(time_remaining)}\n")
        
            