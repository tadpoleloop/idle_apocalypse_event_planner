import re
from state import State, get_event_info
from time import time
from resources import *
from colors import Colors
from IPython.display import clear_output
from move import move_target

#factory function to make a resources "object"
def Resources(blue = 0, green = 0, red = 0, gold = 0, damage = 0):
    return {"blue": blue, "green": green, "red": red, "gold": gold, "damage": damage}

def pretty_print_number(num):
    num = int(num)
    if num < 0:
        m = "-"
        num *= -1
    else:
        m = ""
    if num >= 1000000000000:
        num = (num//10000000000) * 10000000000
        return m + f"{num / 1000000000000:.2f}" + "t "
    elif num >= 1000000000:
        num = (num//10000000) * 10000000
        return m + f"{num / 1000000000:.2f}" + "b "
    elif num >= 1000000:
        num = (num//10000) * 10000
        return m + f"{num / 1000000:.2f}" + "m "
    elif num >= 1000:
        num = (num//10) * 10
        return m + f"{num / 1000:.2f}" + "k "
    elif num > 0:
        return m + f"{num:} "
    else:
        return ""
    
def pretty_print_time(t):
    t = int(t)
    negative = t<0
    t = abs(t)
    days = t // 86400
    hours = (t % 86400) // 3600
    minutes = (t%3600) // 60
    seconds = t % 60
    s = "-" if negative else ""
    if days > 0:
        s += f"{days}d"
    if hours > 0:
        s += f"{hours}h"
    if minutes > 0:
        s += f"{minutes}m"
    if seconds > 0:
        s += f"{seconds}s"
    return s

def print_resources(resources, print_damage = 1):
    s = ""
    s += Colors.BOLD
    s += Colors.color(f"{pretty_print_number(resources['blue']):>8}", "blue")
    s += Colors.color(f"{pretty_print_number(resources['green']):>8}", "green")
    s += Colors.color(f"{pretty_print_number(resources['red']):>8}", "red")
    s += Colors.color(f"{pretty_print_number(resources['gold']):>8}", "gold")
    if print_damage:
        s += Colors.color(f"{pretty_print_number(resources['damage']):>8}", "bold")
    return s

class Dashboard:
    def __init__(self):
        self.progress = 0
        self.event = ""
        self.step = ""
        self.moves = []
        self.last_frame = time()
        self.fps = 12
        self.state = State()
        self.context = None
    def set_progress(self, progress):
        self.progress = progress
    def set_step(self, step):
        self.step = step
    def set_moves(self, moves):
        self.moves = moves
    def set_event(self, event):
        self.event = event
    def set_state(self, state):
        self.state = State().copy(state)
    def set_context(self, context):
        self.context = context
    def show(self, force = False, include_urgency = False):
        if time() - self.last_frame > 1/self.fps or force:
            score = self.state.score_moves(self.moves)
            score_t = self.state.time_moves(self.moves)
            goal = get_event_info()["goal"]
            s = "\n".join([
                f"event: {self.event}",
                f"gem level: {self.state.gem_level}",
                f"goal: {pretty_print_number(goal)}",
                f"{self.step}",
                f"{100 * self.progress:5.1f}% complete" if isinstance(self.progress, float) else str(self.progress),
                f"time remaining: {pretty_print_time(self.state.time - score_t)}",
                f"score: {pretty_print_number(score)}",
                f"{score / goal * 100:5.1f}% of goal",
                print_plan(self.state, self.moves, include_urgency)
            ])
            if self.context is not None:
                self.context.clear_print(s)
            else:
                clear_output(wait = True)
                print(s)
            self.last_frame = time()
            
class Blank(Dashboard):
    def show(self):
        pass
            
def move_to_str(move):
    mapping = {
        int(move_target.CHAMPION) : "c",
        int(move_target.RESOURCE) : "r",
        int(move_target.SPEED)    : "s",
        int(move_target.SPEED2)   : "z",
        int(move_target.DAMAGE)   : "d",
        int(move_target.TOGGLE)   : "t",
        int(move_target.WAIT)     : "w"
    }
    return f"{mapping[move['target']]}{move['index']}{move['meta']}"

def str_to_move(s):
    mapping = {
        "c" : int(move_target.CHAMPION),
        "r" : int(move_target.RESOURCE),
        "s" : int(move_target.SPEED),
        "z" : int(move_target.SPEED2),
        "d" : int(move_target.DAMAGE),
        "t" : int(move_target.TOGGLE),
        "w" : int(move_target.WAIT)    
    }
    if s[0] != "w":
        return {"target": mapping[s[0]], "index": int(s[1]), "meta": int(s[2])}
    else:
        return {"target": int(move_target.WAIT), "index": 0, "meta": int(s[2:])}

def str_to_moves(s):
    moves = []
    for match in re.findall("\w\d+", s):
        moves.append(str_to_move(match))
    return moves

def moves_to_str(moves):
     return "".join(list(map(move_to_str, moves)))
        
def print_plan(root, moves, include_urgency = False):
    """
    A representation of a move sequence
    """
    event_info = get_event_info()
    plan = ""
    state = State().copy(root)
    previous_time = 0
    goal_reached_printed = state.resources['damage'] >= event_info['goal']
    goal_projected_printed = state.resources['damage'] >= event_info['goal']
    COLUMN_WIDTHS = [13, 13, 40, 19, 32, 7]
    WAIT_MOVE = {"target" : move_target.WAIT, "index": 0, "meta": 0}
    LEGEND = [Colors.BLUE, Colors.GREEN, Colors.RED, Colors.GOLD]


    for i, header_name in enumerate(["Δ", "Time", "Resources", "Upgrade", "Cost", "Urgency"]):
        plan += f"{header_name:^{COLUMN_WIDTHS[i]}}" + "|" 
    plan += "\n" + "-"*(sum(COLUMN_WIDTHS) + len(COLUMN_WIDTHS) - 1) + "|\n"
    goal_time = state.time_moves(moves)
    for i, move in enumerate(moves):
        duration = state.get_duration(move)
        if duration >= state.time:
            move = WAIT_MOVE
            duration = state.time
        resources = add_resources(state.resources, mul_resources(state.resources_per_second, duration))
        projected_damage = state.resources["damage"] + state.resources_per_second["damage"] * state.time
        if include_urgency:
            wait_time = State().copy(root).time_moves(
                moves[:i] + [{'target' : move_target.WAIT, 'index': 0, 'meta': 3600 + int(duration)}] + moves[i:]
            )
            urgency = (wait_time - goal_time) / 3600.
            # there's some bug that gives huge urgency, still haven't figured that one out
            if urgency > 1:
                urgency = 1
        else:
            urgency = 0
        if not goal_projected_printed and projected_damage > event_info["goal"]:
            goal_projected_printed = True
            plan += (
                " " * COLUMN_WIDTHS[0] + "|" + 
                f"{pretty_print_time(state.time):{COLUMN_WIDTHS[0]}}|" + 
                f"{print_resources(state.resources)}|" +
                Colors.rainbow(f"{'goal projected':<{COLUMN_WIDTHS[3]}}") + "|" + 
                " " * COLUMN_WIDTHS[4] + "|" + " " * COLUMN_WIDTHS[5] + "|\n"
            )
        if not goal_reached_printed and resources["damage"] > event_info["goal"]:
            goal_reached_printed = True
            time_to_goal = (event_info["goal"] - state.resources["damage"]) / state.resources_per_second["damage"]
            end_time = state.time - time_to_goal
            end_resources = add_resources(state.resources, mul_resources(state.resources_per_second, time_to_goal))
            plan += (
                " " * COLUMN_WIDTHS[0] + "|" + 
                f"{pretty_print_time(end_time):{COLUMN_WIDTHS[0]}}|" + 
                f"{print_resources(end_resources)}|" +
                Colors.rainbow(f"{'goal reached':<{COLUMN_WIDTHS[4]}}") + "|" +
                " "* COLUMN_WIDTHS[4] + "|" + " " * COLUMN_WIDTHS[5] + "|\n"
            )
        if move["target"] == move_target.CHAMPION:
            upgrade = f"{move['index'] + 1}. {event_info['champions'][move['index']]['name'].decode()}"
            cost = event_info["champions"][move["index"]]["upgrade_costs"][move["meta"]]

        elif move["target"] == move_target.RESOURCE:
            upgrade = (
                LEGEND[move['index']] + 
                f"{event_info['resources'][move['index']]['name'].decode():<{COLUMN_WIDTHS[3]}}" + 
                Colors.RESET
            )
            cost = event_info["resources"][move["index"]]["upgrade_costs"][move["meta"]]
        elif move["target"] == move_target.SPEED:
            upgrade = Colors.rainbow(f"{event_info['speed']['name'].decode():<{COLUMN_WIDTHS[3]}}")
            cost = event_info["speed"]["upgrade_costs"][move["meta"]]
        elif move["target"] == move_target.SPEED2:
            upgrade = Colors.rainbow(f"{event_info['speed2']['name'].decode():<{COLUMN_WIDTHS[3]}}")
            cost = event_info["speed2"]["upgrade_costs"][move["meta"]]
        elif move["target"] == move_target.DAMAGE:
            upgrade = Colors.color(f"{event_info['damage']['name'].decode():{COLUMN_WIDTHS[3]}}", 'bold')
            cost = event_info["damage"]["upgrade_costs"][move["meta"]]
        elif move["target"] == move_target.WAIT:
            upgrade = None
            cost = Resources()
        elif move["target"] == move_target.TOGGLE:
            toggle_direction = move["meta"]
            if toggle_direction == 0:
                target_resources = event_info['champions'][move['index']]['revenue'][0]
            else:
                target_resources = event_info['champions'][move['index']]['revenue_toggle'][0]
            for color in ['blue', 'green', 'red', 'gold']:
                if target_resources[color] > 0:
                    color_f = lambda x: Colors.color(x, color)
                    break
            else:
                color_f = lambda x: Colors.color(x, 'bold')
            
            
            if toggle_direction == 0:
                s = f"<<{event_info['champions'][move['index']]['name'].decode()}<<"
                c = "<"
            else:
                s = f">>{event_info['champions'][move['index']]['name'].decode()}>>"
                c = "<"
            s = f"{s:{c}{COLUMN_WIDTHS[3]}}"
            upgrade = color_f(s)
            cost = Resources()
        else:
            raise
        previous_time = state.time
        state.apply_move(move)
        previous_time = previous_time - state.time
        if state.time <= 0 and move["target"] == move_target.WAIT:
            break
        if upgrade is not None:
            plan += (
                f"{pretty_print_time(previous_time):{COLUMN_WIDTHS[0]}}|" + 
                f"{pretty_print_time(state.time):{COLUMN_WIDTHS[0]}}|" + 
                f"{print_resources(resources)}|" + 
                f"{upgrade:{COLUMN_WIDTHS[3]}}|" + 
                f"{print_resources(cost, 0)}|" +
                f"{f'{int(100 * urgency):3d}%':^{COLUMN_WIDTHS[5]}}|\n"
            )
    plan += (
        f"{'End of Event':^{COLUMN_WIDTHS[0]}}|" +
        " " * COLUMN_WIDTHS[1] + "|" + 
        print_resources(state.resources) + "|" + 
        " " * COLUMN_WIDTHS[3] + "|" + 
        " " * COLUMN_WIDTHS[4] + "|" +
        " " * COLUMN_WIDTHS[5] + "|"
    )
    return plan