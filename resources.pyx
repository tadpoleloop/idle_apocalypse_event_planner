#cython: language_level=3

cdef struct Resources:
    double blue, green, red, gold, damage

cdef union ResourcesView:
    Resources *data
    double *view
    
#resource object constructors
cdef Resources Blue(double blue):
    return Resources(blue, 0, 0, 0, 0)
        
cdef Resources Green(double green):
    return Resources(0, green, 0, 0, 0)
                     
cdef Resources Red(double red):
    return Resources(0, 0, red, 0, 0)

cdef Resources Gold(double gold):
    return Resources(0, 0, 0, gold, 0)

cdef Resources Damage(double damage):
    return Resources(0, 0, 0, 0, damage)

cpdef Resources add_resources(Resources r1, Resources r2):
    return Resources(
        r1.blue + r2.blue, 
        r1.green + r2.green, 
        r1.red + r2.red, 
        r1.gold + r2.gold, 
        r1.damage + r2.damage
    )

cpdef Resources mul_resources(Resources r, double a):
    return Resources(r.blue * a, r.green * a, r.red * a, r.gold * a, r.damage * a)

cpdef Resources neg_resources(Resources r):
    return Resources(-r.blue, -r.green, -r.red, -r.gold, -r.damage)

cpdef Resources sub_resources(Resources r1, Resources r2):
    return add_resources(r1, neg_resources(r2))

cpdef Resources truncate_resources(Resources r):
    return Resources(int(r.blue), int(r.green), int(r.red), int(r.gold), int(r.damage))