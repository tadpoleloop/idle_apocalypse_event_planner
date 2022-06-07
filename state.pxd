from event_info cimport EventInfo, MAX_RESOURCES, MAX_CHAMPIONS, MAX_LEVEL
from resources cimport *
from resources import print_resources
from move cimport Move, CHAMPION, RESOURCE, SPEED, DAMAGE, WAIT 
from string_utils import pretty_print_time, pretty_print_number
from colors import Colors

cdef double max_dps = -1

cpdef calculate_max_dps()
    
cdef EventInfo event_info

cdef EventInfo _get_event_info()

cdef class State:
    cdef:
        EventInfo *event_info
        double *max_dps

    cdef public:
        int time
        Resources resources
        Resources resources_per_second
        int ad_boost
        int gem_level
        int champion_levels[MAX_CHAMPIONS]
        bint toggles[MAX_CHAMPIONS]
        int resource_levels[MAX_RESOURCES]
        int speed_level
        int damage_level
        Move log[100]
        int ilog
        
    cpdef State copy(self, State state)
                
    cpdef int get_duration(self, Move move)

    cpdef list legal_moves(self)
    
    cdef int _legal_moves(self, Move *moves) except *
    
    cpdef void update_resources_per_second(self) except *
    
    cpdef apply_move(self, dict pmove)
        
    cdef void _apply_move(self, Move move) except *

    cpdef double score_moves(self, list moves)
    
    cpdef double time_moves(self, list moves)
                
#     cpdef double upper_bound(self)
    
#     cpdef double lower_bound(self)