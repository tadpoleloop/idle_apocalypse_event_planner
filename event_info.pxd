from resources cimport Resources

cdef enum:
    MAX_CHAMPIONS = 8
    MAX_RESOURCES = 4
    MAX_LEVEL = 10

cdef struct EventInfo:
    unsigned long long goal
    char champion_names[MAX_CHAMPIONS][30]
    char resource_names[MAX_RESOURCES][30]
    int n_resources
    int n_champions
    int champion_max_level[MAX_CHAMPIONS]
    int resource_max_level[MAX_RESOURCES]
    int speed_max_level
    int damage_max_level
    Resources champion_upgrade_costs[MAX_CHAMPIONS][MAX_LEVEL]
    Resources resource_upgrade_costs[MAX_RESOURCES][MAX_LEVEL]
    Resources speed_upgrade_costs[MAX_LEVEL]
    Resources damage_upgrade_costs[MAX_LEVEL]
    Resources champion_revenue[MAX_CHAMPIONS][MAX_LEVEL]
    Resources champion_revenue_swap[MAX_CHAMPIONS][MAX_LEVEL]
    int champion_duration[MAX_CHAMPIONS]