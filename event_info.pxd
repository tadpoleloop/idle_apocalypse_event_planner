from resources cimport Resources

cdef enum:
    MAX_CHAMPIONS = 8
    MAX_RESOURCES = 4
    MAX_LEVEL = 10
    
cdef struct ChampionInfo:
    char name[30]
    int duration
    int max_level
    int has_swap
    Resources upgrade_costs[MAX_LEVEL]
    Resources revenue[MAX_LEVEL]
    Resources revenue_swap[MAX_LEVEL]
    
cdef struct ResourceInfo:
    char name[30]
    int max_level
    Resources upgrade_costs[MAX_LEVEL]
    
cdef struct SpeedInfo:
    int max_level
    Resources upgrade_costs[MAX_LEVEL]
    
cdef struct DamageInfo:
    int max_level
    Resources upgrade_costs[MAX_LEVEL]
    
cdef struct EventInfo:
    unsigned long long goal
    int n_champions
    int n_resources
    ChampionInfo champions[MAX_CHAMPIONS]
    ResourceInfo resources[MAX_RESOURCES]
    SpeedInfo speed
    DamageInfo damage