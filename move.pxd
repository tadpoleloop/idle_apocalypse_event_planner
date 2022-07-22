cpdef enum move_target:
    CHAMPION, RESOURCE, SPEED, SPEED2, DAMAGE, TOGGLE, WAIT
    

cdef struct Move:
    move_target target #Could use a union move type for each target type instead of two ints. 
    int index
    int meta #level for upgrades, time for waits and direction for toggle. Somewhat redundant