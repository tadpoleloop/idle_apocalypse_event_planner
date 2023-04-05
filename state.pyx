# cython: cdivision=True
# cython: language_level=3

from event_info cimport EventInfo, MAX_RESOURCES, MAX_CHAMPIONS, MAX_LEVEL, ChampionInfo, ResourceInfo, SpeedInfo, DamageInfo
from resources cimport *
from move cimport Move, move_target
import json
    
cdef EventInfo event_info

cdef EventInfo _get_event_info():
    return event_info

def get_event_info():
    return event_info

cdef set_resources(Resources *r, list l):
    r[0] = Resources(l[0], l[1], l[2], l[3], l[4])

cdef set_champion_info(ChampionInfo *c, dict d):
    cdef int i
    c.name = d['name'].encode('UTF-8') + b'\0' * (30 - len(d['name']))
    c.duration = d["duration"]
    c.max_level = d["max_level"]
    c.has_swap = d.get("has_swap", 0)
    c.role = d.get("role", 0)
    for i in range(c.max_level):
        set_resources(&c.upgrade_costs[i], d["upgrade_costs"][i])
        set_resources(&c.revenue[i], d["revenue"][i])
        set_resources(&c.revenue_toggle[i], d["revenue_toggle"][i])
        
cdef set_resource_info(ResourceInfo *r, dict d):
    cdef int i
    r.name = d['name'].encode('UTF-8') + b'\0' * (30 - len(d['name']))
    r.max_level = d["max_level"]
    for i in range(r.max_level):
        set_resources(&r.upgrade_costs[i], d["upgrade_costs"][i])
        
cdef set_damage_info(DamageInfo *d, dict py_d):
    cdef int i
    name = py_d.get('name', 'damage')
    d.name = name.encode('UTF-8') + b'\0' * (30 - len(name))
    d.max_level = py_d["max_level"]
    for i in range(d.max_level):
        set_resources(&d.upgrade_costs[i], py_d["upgrade_costs"][i])

cdef set_speed_info(SpeedInfo *s, dict d):
    if not d:
        return #to handle if the json file has no speed2 info
    cdef int i
    name = d.get('name', 'speed')
    s.name = name.encode('UTF-8') + b'\0' * (30 - len(name))
    s.max_level = d["max_level"]
    for i in range(s.max_level):
        set_resources(&s.upgrade_costs[i], d["upgrade_costs"][i])
    
def set_event_info(d):
    """
    converts a python dictionary to an EventInfo struct
    """
    global event_info
    cdef ResourcesView view
    event_info.goal = d["goal"]
    event_info.n_resources = d["n_resources"]
    event_info.n_champions = d["n_champions"]
    for i in range(d["n_champions"]):
        #ugly string hacking for python string to c string
        set_champion_info(&event_info.champions[i], d["champions"][i])
    for i in range(d["n_resources"]):
        set_resource_info(&event_info.resources[i], d["resources"][i])
    set_speed_info(&event_info.speed, d["speed"])
    if 'speed2' in d:
        event_info.has_speed2 = 1
        set_speed_info(&event_info.speed2, d['speed2'])
    else:
        event_info.has_speed2 = 0
    set_damage_info(&event_info.damage, d["damage"])
#     calculate_max_dps()

cdef class State:
    def __cinit__(self):
        global event_info
        global max_dps
        self.event_info = &event_info
#         self.max_dps = &max_dps
        
    def __init__(self):
        self.time = 3 * 24 * 3600
        self.resources = [0, 0, 0, 0, 0]
        self.resources_per_second = [0, 0, 0, 0, 0]
        self.ad_boost = 1
        self.gem_level = 0
        self.boost_level = 1
        cdef int i
        for i in range(MAX_CHAMPIONS):
            self.champion_levels[i] = 0
            self.toggles[i] = False
        for i in range(MAX_RESOURCES):
            self.resource_levels[i] = 0
        self.speed_level = 0
        self.speed2_level = 0
        self.damage_level = 0
#         self.ilog = 0
        
    @staticmethod
    def set_event_by_name(event_name):
        with open("event_info/" + event_name + ".json", "r") as infile:
            set_event_info(json.load(infile))
        
        
    cpdef State copy(self, State state):
        self.time = state.time
        self.resources = state.resources
        self.resources_per_second = state.resources_per_second
        self.ad_boost = state.ad_boost
        self.gem_level = state.gem_level
        self.boost_level = state.boost_level
        self.boost_level = state.boost_level
        self.champion_levels = state.champion_levels
        self.toggles = state.toggles
        self.resource_levels = state.resource_levels
        self.speed_level = state.speed_level
        self.speed2_level = state.speed2_level
        self.damage_level = state.damage_level
#         self.ilog = state.ilog
#         self.log = state.log
        return self
                
    
    cpdef int get_duration(self, Move move):
        cdef:
            Resources cost, needed
            int i, duration, resource_duration
            ResourcesView needed_view, rps_view
        if move.target == move_target.CHAMPION:
            cost = self.event_info.champions[move.index].upgrade_costs[move.meta]
        elif move.target == move_target.RESOURCE:
            cost = self.event_info.resources[move.index].upgrade_costs[move.meta]
        elif move.target == move_target.SPEED:
            cost = self.event_info.speed.upgrade_costs[move.meta]
        elif move.target == move_target.SPEED2:
            cost = self.event_info.speed2.upgrade_costs[move.meta]
        elif move.target == move_target.DAMAGE:
            cost = self.event_info.damage.upgrade_costs[move.meta]
        elif move.target == move_target.TOGGLE:
            return 0
        elif move.target == move_target.WAIT:
            if move.meta == 0:
                return self.time
            else:
                return move.meta
        needed = sub_resources(cost, self.resources)
        duration = 0
        needed_view.data = &needed
        rps_view.data = &self.resources_per_second
        for i in range(4):
            if needed_view.view[i] <= 0:
                continue
            if rps_view.view[i] <= 0:
                duration = 2 * self.time #should signal that this move can't happen
                break
            resource_duration = <int>(needed_view.view[i] / rps_view.view[i])
            if resource_duration > duration:
                duration = resource_duration
        return duration + 1

    cpdef list legal_moves(self):
        """
        python wrapper for move generation
        """
        cdef Move moves[100]
        n_moves = self._legal_moves(moves)
        return [moves[i] for i in range(n_moves)]
    
    cdef int _legal_moves(self, Move *moves) except *:
        """
        c-level move generation
        sorted by move duration with insertion sorts while building the move list, might be a bit slow because of it
        """
        cdef:
            int n_moves = 0
            int index, level, i, j
            double durations[100]
            double duration
        
        for index in range(self.event_info.n_champions):
            level = self.champion_levels[index]
            if level == self.event_info.champions[index].max_level:
                continue
            duration = self.get_duration(Move(move_target.CHAMPION, index, level)) 
            if duration < self.time:
                for i in range(n_moves):
                    if duration < durations[i]:
                        break
                else:
                    i = n_moves
                for j in range(n_moves, i, -1):
                    durations[j] = durations[j-1]
                    moves[j] = moves[j-1]
                moves[i] = Move(move_target.CHAMPION, index, level)
                durations[i] = duration
                n_moves += 1
            if level == 0:
                break
        
        for index in range(self.event_info.n_resources):
            level = self.resource_levels[index]
            if level == self.event_info.resources[index].max_level:
                continue
            duration = self.get_duration(Move(move_target.RESOURCE, index, level)) 
            if duration < self.time:
                for i in range(n_moves):
                    if duration < durations[i]:
                        break
                else:
                    i = n_moves
                for j in range(n_moves, i, -1):
                    durations[j] = durations[j-1]
                    moves[j] = moves[j-1]
                moves[i] = Move(move_target.RESOURCE, index, level)
                durations[i] = duration
                n_moves += 1
        level = self.speed_level
        if level < self.event_info.speed.max_level:
            duration = self.get_duration(Move(move_target.SPEED, 0, level)) 
            if duration < self.time:
                for i in range(n_moves):
                    if duration < durations[i]:
                        break
                else:
                    i = n_moves
                for j in range(n_moves, i, -1):
                    durations[j] = durations[j-1]
                    moves[j] = moves[j-1]
                moves[i] = Move(move_target.SPEED, 0, level)
                durations[i] = duration
                n_moves += 1
        if self.event_info.has_speed2:
            level = self.speed2_level
            if level < self.event_info.speed2.max_level:
                duration = self.get_duration(Move(move_target.SPEED2, 0, level)) 
                if duration < self.time:
                    for i in range(n_moves):
                        if duration < durations[i]:
                            break
                    else:
                        i = n_moves
                    for j in range(n_moves, i, -1):
                        durations[j] = durations[j-1]
                        moves[j] = moves[j-1]
                    moves[i] = Move(move_target.SPEED2, 0, level)
                    durations[i] = duration
                    n_moves += 1
        level = self.damage_level
        if level < self.event_info.damage.max_level:
            duration = self.get_duration(Move(move_target.DAMAGE, 0, level)) 
            if duration < self.time:
                for i in range(n_moves):
                    if duration < durations[i]:
                        break
                else:
                    i = n_moves
                for j in range(n_moves, i, -1):
                    durations[j] = durations[j-1]
                    moves[j] = moves[j-1]
                moves[i] = Move(move_target.DAMAGE, 0, level)
                durations[i] = duration
                n_moves += 1
                
        if n_moves == 0:
            n_moves = 1
            moves[0] = Move(move_target.WAIT, 0, 0)
            
        #tack on toggles behind WAIT because if toggles are the only move then WAIT should be one of the moves to choose
        for index in range(self.event_info.n_champions):
            if self.event_info.champions[index].has_swap and self.champion_levels[index] > 0:
                moves[n_moves] = Move(move_target.TOGGLE, index, self.toggles[index] ^ 1)
                n_moves += 1
                
        return n_moves
    
    cpdef void update_resources_per_second(self) except *:
        cdef int i, j
        cdef Resources revenue
        cdef ResourcesView revenue_view
        revenue_view.data = &revenue
        self.resources_per_second = Resources(0, 0, 0, 0, 0)
        for i in range(self.event_info.n_champions):
            if self.champion_levels[i] > 0:
                if self.event_info.champions[i].role == 0:
                    speed = 0.05 * self.speed_level + 0.25 * self.ad_boost
                else:
                    speed = 0.05 * self.speed2_level
                if self.toggles[i]:
                    revenue = self.event_info.champions[i].revenue_toggle[self.champion_levels[i] - 1]
                else:
                    revenue = self.event_info.champions[i].revenue[self.champion_levels[i] - 1]
                #we are assuming that a champion only makes one kind of resource
                for j in range(MAX_RESOURCES):
                    if revenue_view.view[j] > 0:
                        revenue_view.view[j] += self.resource_levels[j] + self.gem_level
                self.resources_per_second = add_resources(
                    self.resources_per_second, 
                    mul_resources(
                        revenue, 
                        1. / self.event_info.champions[i].duration / (1 - speed)
                    )
                )
        self.resources_per_second.damage *= (1 + 0.25 * self.damage_level + self.boost_level)
        
    cpdef void apply_move(self, Move move) except *:
        cdef int wait
        cdef Resources cost
        
        wait = self.get_duration(move)
            
        if wait >= self.time:
            wait = self.time
            cost = Resources(0, 0, 0, 0, 0)
        
        elif move.target == move_target.CHAMPION:
            cost = self.event_info.champions[move.index].upgrade_costs[move.meta]
            self.champion_levels[move.index] += 1
        
        elif move.target == move_target.RESOURCE:
            cost = self.event_info.resources[move.index].upgrade_costs[move.meta]
            self.resource_levels[move.index] += 1
            
        elif move.target == move_target.SPEED:
            cost = self.event_info.speed.upgrade_costs[move.meta]
            self.speed_level += 1
                    
        elif move.target == move_target.SPEED2:
            cost = self.event_info.speed2.upgrade_costs[move.meta]
            self.speed2_level += 1
            
        elif move.target == move_target.DAMAGE:
            cost = self.event_info.damage.upgrade_costs[move.meta]
            self.damage_level += 1
            
        elif move.target == move_target.TOGGLE:
            cost = Resources(0, 0, 0, 0, 0)
            self.toggles[move.index] = move.meta
            
        elif move.target == move_target.WAIT:
            cost = Resources(0, 0, 0, 0, 0)
            
        else:
            raise ValueError
            
        generated = mul_resources(self.resources_per_second, wait)
        self.resources = add_resources(self.resources, sub_resources(generated, cost))
        self.time -= wait
        self.update_resources_per_second()

    cpdef double score_moves(self, list moves):
        """
        Simulate move plan until time runs out
        """
        cdef State state
        state = State().copy(self)
        for move in moves:
            state.apply_move(move)
        return state.resources.damage
    
    cpdef double time_moves(self, list moves):
        """
        Simulate move plan and then interpolate the end-time
        """
        cdef:
            int TIME_CONSTANT, end_time, start_time
            double end_damage, start_damage
            State state
        state = State().copy(self)
        TIME_CONSTANT = 100 * 24 * 3600
        state.time = TIME_CONSTANT
        if state.resources.damage >= state.event_info.goal:
            return 0
        for move in moves:
            start_damage = state.resources.damage
            start_time = state.time
            state.apply_move(move)
            #interpolate time
            if state.resources.damage >= state.event_info.goal:
                end_damage = state.resources.damage
                end_time = state.time
                goal_time = (
                    start_time + 
                    (end_time - start_time) / (end_damage - start_damage) * (state.event_info.goal - start_damage)
                )
                return TIME_CONSTANT - goal_time
        return TIME_CONSTANT
    
    @staticmethod
    def set_event_by_name(event_name):
        with open("event_info/" + event_name + ".json", "r") as infile:
            set_event_info(json.load(infile))
    