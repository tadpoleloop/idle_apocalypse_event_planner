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
    days = t // 86400
    hours = (t % 86400) // 3600
    minutes = (t%3600) // 60
    seconds = t % 60
    s = ""
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
        self.step = ""
        self.score = 0
        self.last_frame = time()
        self.fps = 24
        self.state = State()
    def set_progress(self, progress):
        self.progress = progress
    def set_step(self, step):
        self.step = step
    def set_score(self, score):
        self.score = score
    def set_moves(self, moves):
        self.moves = moves
    def set_event(self, event):
        self.event = event
    def set_goal(self, goal):
        self.goal = goal
    def set_state(self, state):
        self.state = State().copy(state)
    def show(self, force = False):
        if time() - self.last_frame > 1/self.fps or force:
            clear_output(wait = True)
            print(
                f"event: {self.event}" +
                f"\ngoal: {pretty_print_number(self.goal)}" + 
                f"\n{self.step}" + 
                (f"\n{100 * self.progress:5.1f}% complete" if isinstance(self.progress, float) else self.progress) + 
                f"\nscore: {pretty_print_number(self.score)}" + 
                f"\n{self.score / self.goal * 100:5.1f}% of goal" + 
                "\n" + print_plan(self.state, self.moves)
            )
            self.last_frame = time()
            
class Blank(Dashboard):
    def show(self):
        pass
            
def move_to_str(move):
    """
    hard coding these enum values, will need to rewrite this if those values change :s
    """
    mapping = {0 : "c", 1 : "r", 2 : "s", 3 : "d", 4 : "w"}
    return f"{mapping[move['target']]}{move['index']}{move['level']}"

def str_to_move(s):
    mapping = {"c" : 0, "r" : 1, "s" : 2, "d" : 3, "w" : 4}
    if s[0] != "w":
        return {"target": mapping[s[0]], "index": int(s[1]), "level": int(s[2])}
    else:
        return {"target": 4, "index": int(s[1:]), "level": 0}

def str_to_moves(s):
    moves = []
    for match in re.findall("\w\d+", s):
        moves.append(str_to_move(match))
    return moves

def moves_to_str(moves):
     return "".join(list(map(move_to_str, moves)))
        
def print_plan(root, moves):
    """
    A representation of a move sequence
    """
    event_info = get_event_info()
    plan = ""
    state = State().copy(root)
    goal_reached_printed = False
    goal_projected_printed = False
    COLUMN_WIDTHS = [13, 40, 17, 32, 7]
    WAIT_MOVE = {"target" : move_target.WAIT, "index": 0, "level": 0}
    Colors.LEGEND = [Colors.BLUE, Colors.GREEN, Colors.RED, Colors.GOLD]


    for i, header_name in enumerate(["Time", "Resources", "Upgrade", "Cost", "Urgency"]):
        plan += f"{header_name:^{COLUMN_WIDTHS[i]}}" + "|" 
    plan += "\n" + "-"*(sum(COLUMN_WIDTHS) + len(COLUMN_WIDTHS) - 1) + "|\n"
    goal_time = state.time_moves(moves)
    for i, move in enumerate(moves):
        if move["target"] != move_target.WAIT:
            duration = state.get_duration(move)
        else:
            duration = move["index"]
            if duration == 0:
                duration = state.time
        if duration >= state.time:
            move = WAIT_MOVE
            duration = state.time
        resources = add_resources(state.resources, mul_resources(state.resources_per_second, duration))
        projected_damage = state.resources["damage"] + state.resources_per_second["damage"] * state.time
        wait_time = State().copy(root).time_moves(
            moves[:i] + [{'target' : move_target.WAIT, 'index': 3600 + int(duration), 'level': 0}] + moves[i:]
        )
        urgency = (wait_time - goal_time) / 3600
        if not goal_projected_printed and projected_damage > event_info["goal"]:
            goal_projected_printed = True
            plan += (
                f"{pretty_print_time(state.time):{COLUMN_WIDTHS[0]}}|" + 
                f"{print_resources(state.resources)}|" +
                Colors.rainbow(f"{'goal projected':<{COLUMN_WIDTHS[2]}}") + "|" + 
                " " * COLUMN_WIDTHS[3] + "|" + " " * COLUMN_WIDTHS[4] + "|\n"
            )
        if not goal_reached_printed and resources["damage"] > event_info["goal"]:
            goal_reached_printed = True
            time_to_goal = (event_info["goal"] - state.resources["damage"]) / state.resources_per_second["damage"]
            end_time = state.time - time_to_goal
            end_resources = add_resources(state.resources, mul_resources(state.resources_per_second, time_to_goal))
            plan += (
                f"{pretty_print_time(end_time):{COLUMN_WIDTHS[0]}}|" + 
                f"{print_resources(end_resources)}|" +
                Colors.rainbow(f"{'goal reached':<{COLUMN_WIDTHS[2]}}") + "|" +
                " "* COLUMN_WIDTHS[3] + "|" + " " * COLUMN_WIDTHS[4] + "|\n"
            )
        if move["target"] == move_target.CHAMPION:
            upgrade = f"{move['index'] + 1}. {event_info['champion_names'][move['index']].decode()}"
            cost = event_info["champion_upgrade_costs"][move["index"]][move["level"]]

        elif move["target"] == move_target.RESOURCE:
            upgrade = (
                Colors.LEGEND[move['index']] + 
                f"{event_info['resource_names'][move['index']].decode():<{COLUMN_WIDTHS[2]}}" + 
                Colors.RESET
            )
            cost = event_info["resource_upgrade_costs"][move["index"]][move["level"]]
        elif move["target"] == move_target.SPEED:
            upgrade = Colors.rainbow(f"{'speed':<{COLUMN_WIDTHS[2]}}")
            cost = event_info["speed_upgrade_costs"][move["level"]]
        elif move["target"] == move_target.DAMAGE:
            upgrade = Colors.color(f"{'damage':{COLUMN_WIDTHS[2]}}", 'bold')
            cost = event_info["damage_upgrade_costs"][move["level"]]
        elif move["target"] == move_target.WAIT:
            upgrade = "wait"
            cost = Resources()
        else:
            raise
        state.apply_move(move)
        if state.time <= 0 and move["target"] == move_target.WAIT:
            break
        plan += (
            f"{pretty_print_time(state.time):{COLUMN_WIDTHS[0]}}|" + 
            f"{print_resources(resources)}|" + 
            f"{upgrade:{COLUMN_WIDTHS[2]}}|" + 
            f"{print_resources(cost, 0)}|" +
            f"{f'{int(100 * urgency):3d}%':^{COLUMN_WIDTHS[4]}}|\n"
        )
    plan += (
        f"{'End of Event':^{COLUMN_WIDTHS[0]}}|" +
        print_resources(state.resources) + "|" + 
        " " * COLUMN_WIDTHS[2] + "|" + 
        " " * COLUMN_WIDTHS[3] + "|" +
        " " * COLUMN_WIDTHS[4] + "|"
    )
    return plan