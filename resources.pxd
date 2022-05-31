cdef struct Resources:
    double blue, green, red, gold, damage

cdef union ResourcesView:
    Resources *data
    double *view
    
cdef Resources Blue(double blue)
        
cdef Resources Green(double green)
                     
cdef Resources Red(double red)

cdef Resources Gold(double gold)

cdef Resources Damage(double damage)

cpdef Resources add_resources(Resources r1, Resources r2)

cpdef Resources mul_resources(Resources r, double a)

cpdef Resources neg_resources(Resources r)

cpdef Resources sub_resources(Resources r1, Resources r2)

cpdef Resources truncate_resources(Resources r)