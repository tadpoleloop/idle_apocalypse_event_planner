from resources cimport Resources

cdef enum:
    MAX_CHAMPIONS = 8
    MAX_RESOURCES = 4
    MAX_LEVEL = 10
    STRING_LENGTH = 30
    
cdef struct ChampionInfo:
    char name[STRING_LENGTH]
    int role
    int duration
    int max_level
    int has_swap
    Resources upgrade_costs[MAX_LEVEL]
    Resources revenue[MAX_LEVEL]
    Resources revenue_toggle[MAX_LEVEL]
    
cdef struct ResourceInfo:
    char name[STRING_LENGTH]
    int max_level
    Resources upgrade_costs[MAX_LEVEL]
    
cdef struct SpeedInfo:
    char name[STRING_LENGTH]
    int max_level
    Resources upgrade_costs[MAX_LEVEL]
    
cdef struct DamageInfo:
    char name[STRING_LENGTH]
    int max_level
    Resources upgrade_costs[MAX_LEVEL]
    
cdef struct EventInfo:
    unsigned long long goal
    int n_champions
    int n_resources
    int has_speed2
    ChampionInfo champions[MAX_CHAMPIONS]
    ResourceInfo resources[MAX_RESOURCES]
    SpeedInfo speed
    SpeedInfo speed2
    DamageInfo damage