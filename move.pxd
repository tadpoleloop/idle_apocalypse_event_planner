cpdef enum move_target:
    CHAMPION, RESOURCE, SPEED, DAMAGE, TOGGLE, WAIT
    
cdef struct Move:
    move_target target
    int index #or duration for wait
    int level